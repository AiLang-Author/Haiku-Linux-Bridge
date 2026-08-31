KERNEL_BASE {
	global:
		init_hardware;
		init_driver;
		uninit_driver;
		publish_devices;
		find_device;
		api_version;
		sys_compat_lstar;
		sys_compat_dispatch_fast;
		gOrigLstar;
		gLinuxCR3;
	local:
		*;
};
