---
page: https://idle.run/linphone-raspi
title: "Linphone on Raspberry Pi"
tags: raspberry pi linphone sip
date: 2018-11-12
---

## Overview

This does not QUITE work as expected, but is kept for reference.
Compiles correctly, but segfaults when trying to make a call.

## Requirements

Install Docker as described here: https://www.raspberrypi.org/blog/docker-comes-to-raspberry-pi/

```
curl -sSL https://get.docker.com | sh
```

## Build

Run `./build.sh`

### v4l2

Enable module to create the `/dev/video0` device for the camera

```
modprobe bcm2835-v4l2
echo bcm2835-v4l2 >> /etc/modules
```

### ALSA device ID

Check `arecord -L` to see device ID for alsa device. In my case it's `hw:1`
