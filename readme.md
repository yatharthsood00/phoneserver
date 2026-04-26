# Phone Media Server

Here are the config files for my media server, that runs over Termux on my old Redmi Note 10 Pro Android phone. The key components of which are: a file server for general file browsing + Obsidian (via copyparty, obsidian uses WebDAV on the same), a zeroconf/UPnP setup for DLNA devices (via miniDLNA, for a TV on the network, VLC Media Player, etc.), a BitTorrent management service (via aria2, and an AriaNg frontend, also hosted on copyparty), and a meta-service for toggling a TP-Link P110 Smart Plug that keeps the phone charging till 80% and discharging till 75% to preserve battery life on this aging device.

Also, I'm evaluating some more services. Notably, slskd for using Soulseek over the phone, headless, with a baked-in UI for file management, downloads, etc. And I formerly used Nicotine+ for the same, but it didn't work out so well. Regardless, we press on.

All 4 of the above services are run in a single ```tmux``` session, which Termux is able to start (after killing any lingering processes) by executing start-services.sh. This script is also stored in ```/.termux/boot``` so that Termux runs it at device restart, so that these services are run without interruptions.

Additionally, Tailscale is also set up via the app so that I can access this phone over the Internet when I'm on my tailnet. Also additionally, my own domain https://share.ysood.xyz allows me to authenticate copyparty, and then create shareable links for anyone across the world to get my photos, etc. Yeah, just photos I took, don't worry about it.
