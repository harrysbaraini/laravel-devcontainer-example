host := `uname -a`
set positional-arguments

setup:
    #!/bin/bash
    if [ ! -f .env ]; then
        cp .env.example .env
    fi
    composer install
    php artisan key:generate
    php artisan migrate
    php artisan storage:link

dev:
    npm run install && npm run dev
