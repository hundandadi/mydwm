#!/bin/sh

sensors | grep Package | awk '{print substr($4, 2, length($0)-3)}'