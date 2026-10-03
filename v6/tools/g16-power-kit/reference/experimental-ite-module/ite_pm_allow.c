
#include <linux/module.h>
#include <linux/usb.h>
#include <linux/pm_runtime.h>

static struct usb_interface *target;
static bool dropped;

static int find_ite(struct usb_device *udev, void *data)
{
    struct usb_interface *intf;

    if (le16_to_cpu(udev->descriptor.idVendor) != 0x0b05 ||
        le16_to_cpu(udev->descriptor.idProduct) != 0x19b6)
        return 0;

    intf = usb_ifnum_to_if(udev, 0);
    if (!intf)
        return 0;

    target = usb_get_intf(intf);
    return 1;
}

static int __init ite_pm_test_init(void)
{
    int usage;

    usb_for_each_dev(NULL, find_ite);

    if (!target) {
        pr_err("ite_pm_test: 0b05:19b6 interface 0 not found\n");
        return -ENODEV;
    }

    usage = atomic_read(&target->dev.power.usage_count);

    pr_info("ite_pm_test: BEFORE auto=%u usage=%d status=%d disable=%u\n",
        target->dev.power.runtime_auto,
        usage,
        target->dev.power.runtime_status,
        target->dev.power.disable_depth);

    /*
     * Safety: only run on the exact state we measured.
     */
    if (usage != 1 ||
        !target->dev.power.runtime_auto ||
        target->dev.power.disable_depth != 0) {
        pr_err("ite_pm_test: unexpected PM state; refusing to modify it\n");
        usb_put_intf(target);
        target = NULL;
        return -EINVAL;
    }

    /*
     * Drop exactly one interface PM reference.
     * usb_autopm_put_interface() will attempt runtime idle/suspend.
     */
    usb_autopm_put_interface(target);
    dropped = true;

    pr_info("ite_pm_test: AFTER PUT auto=%u usage=%d status=%d\n",
        target->dev.power.runtime_auto,
        atomic_read(&target->dev.power.usage_count),
        target->dev.power.runtime_status);

    return 0;
}

static void __exit ite_pm_test_exit(void)
{
    int ret = 0;

    if (!target)
        return;

    /*
     * Restore exactly the one reference we removed.
     */
    if (dropped)
        ret = usb_autopm_get_interface(target);

    pr_info("ite_pm_test: RESTORED ret=%d auto=%u usage=%d status=%d\n",
        ret,
        target->dev.power.runtime_auto,
        atomic_read(&target->dev.power.usage_count),
        target->dev.power.runtime_status);

    usb_put_intf(target);
}

module_init(ite_pm_test_init);
module_exit(ite_pm_test_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Temporary ASUS ITE 0b05:19b6 PM reference test");
