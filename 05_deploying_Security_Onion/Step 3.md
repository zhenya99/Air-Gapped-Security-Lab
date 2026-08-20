### Step 3: Complete the Installation

Allow the base OS installation to complete. The installer will partition the 250 GB `ext-ssd` disk and unpack the core operating system files. 

When the installation finishes, the system will prompt you to reboot. Press `Enter` to confirm. 

As the VM restarts, it will bypass the ISO (due to the `order=ide2;scsi0` boot configuration we set earlier) and boot directly into your newly installed Security Onion command-line interface.

