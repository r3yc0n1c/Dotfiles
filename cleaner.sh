#!/bin/bash

find . -type f -executable -not -path '*/.git/*' -not -name "*.sh" -delete
