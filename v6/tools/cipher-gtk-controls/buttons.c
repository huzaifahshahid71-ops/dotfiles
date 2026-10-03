#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* GTK module; resolve the already-loaded GTK3 ABI, no private GTK headers. */
static void (*set_property)(void *, const char *, ...);
static void (*get_property)(void *, const char *, ...);
static void (*free_value)(void *);
static int changing;
static void enforce_layout(void *settings, void *spec, void *data) {
    (void)spec; (void)data;
    if (changing) return;
    char *current = NULL;
    get_property(settings, "gtk-decoration-layout", &current, NULL);
    if (!current || strcmp(current, "close,minimize,maximize:")) {
        changing = 1;
        set_property(settings, "gtk-decoration-layout", "close,minimize,maximize:", NULL);
        changing = 0;
    }
    free_value(current);
}

void gtk_module_init(int *argc, char ***argv) {
    (void)argc; (void)argv;
    const char *enabled = getenv("CIPHER_GTK_PREVIEW");
    const char *css = getenv("CIPHER_GTK_BUTTONS_CSS");
    if (!enabled || strcmp(enabled, "1") || !css) return;
#define RESOLVE(type, name) type name = (type)dlsym(RTLD_DEFAULT, #name)
    /* Declarations are explicit to keep the exported GTK module ABI small. */
    unsigned (*major)(void) = dlsym(RTLD_DEFAULT, "gtk_get_major_version");
    void *(*settings_default)(void) = dlsym(RTLD_DEFAULT, "gtk_settings_get_default");
    void *(*screen_default)(void) = dlsym(RTLD_DEFAULT, "gdk_screen_get_default");
    void *(*provider_new)(void) = dlsym(RTLD_DEFAULT, "gtk_css_provider_new");
    int (*load_css)(void *, const char *, void **) = dlsym(RTLD_DEFAULT, "gtk_css_provider_load_from_path");
    void (*add_provider)(void *, void *, unsigned) = dlsym(RTLD_DEFAULT, "gtk_style_context_add_provider_for_screen");
    unsigned long (*connect_signal)(void *, const char *, void (*)(void *, void *, void *), void *, void *, int) = dlsym(RTLD_DEFAULT, "g_signal_connect_data");
    void (*unref)(void *) = dlsym(RTLD_DEFAULT, "g_object_unref");
    void (*error_free)(void *) = dlsym(RTLD_DEFAULT, "g_error_free");
    set_property = dlsym(RTLD_DEFAULT, "g_object_set");
    get_property = dlsym(RTLD_DEFAULT, "g_object_get");
    free_value = dlsym(RTLD_DEFAULT, "g_free");
    if (!major || major() != 3 || !settings_default || !screen_default ||
        !provider_new || !load_css || !add_provider || !connect_signal ||
        !unref || !error_free || !set_property || !get_property || !free_value) {
        fputs("Cipher GTK: GTK3 module ABI unavailable; using standard controls.\n", stderr);
        return;
    }
    void *screen = screen_default(), *settings = settings_default();
    if (!screen || !settings) return;
    void *provider = provider_new(), *error = NULL;
    if (!load_css(provider, css, &error)) {
        fputs("Cipher GTK: CSS failed to load; using standard controls.\n", stderr);
        if (error) error_free(error);
        unref(provider);
        return;
    }
    add_provider(screen, provider, 601);
    unref(provider);
    connect_signal(settings, "notify::gtk-decoration-layout", enforce_layout, NULL, NULL, 0);
    enforce_layout(settings, NULL, NULL);
    fputs("CIPHER_GTK_OK: GTK3 traffic lights and left button layout enabled for this process.\n", stderr);
}
