#!/bin/bash

if ! generamba >/dev/null 2>&1; then
    echo "Generamba is required to continue... Run gem install generamba to install" >&2
    exit 1
fi

generamba template install
generamba gen "$1" "viper-code-layout"