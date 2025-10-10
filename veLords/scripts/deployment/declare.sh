#!/bin/bash

cd ../../ && \
scarb --release build && \
cd - && \
node declare