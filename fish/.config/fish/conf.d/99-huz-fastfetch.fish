if status is-interactive
    if command -q fastfetch
        if not set -q __HUZ_FASTFETCH_SHOWN
            set -g __HUZ_FASTFETCH_SHOWN 1
            fastfetch --config ~/.local/share/huz-terminal/fastfetch.jsonc
        end
    end
end
