# Software Upgrade using gNOI

SR Linux is a modern Network Operating System (NOS), and it should come as no surprise that modern management tools like [gRPC](https://grpc.io) can be used to manage switches or routers running this NOS.

In this article, we provide a step-by-step guide to perform a software upgrade (or a downgrade) using the gRPC gNOI service.

## Introduction

gRPC is an HTTP/2-based RPC (Remote Procedure Call) framework that allows for the management and operation of a destination device. gRPC operates using a client-server model. In the networking world, the server is typically a switch or router.

Within the gRPC framework, the following services are defined for specific functions. Each service has a set of defined RPCs, and each RPC has a set of inputs and output methods.

- gNMI (gRPC-based Network Management Interface):  
  gNMI RPCs can be used to configure, retrieve state, or stream telemetry from a destination device. This is by far the most popular gRPC service in the networking industry today.

- gNOI (gRPC-based Network Operations Interface):  
  gNOI RPCs can be used to manage device operations such as ping, traceroute, reboot, and software upgrade.

- gNSI (gRPC-based Network Security Interface):  
  gNSI RPCs can be used to manage security and accounting-related configuration.

- gRIBI (gRPC-based Routing Information Base Injection):  
  gRIBI RPCs can be used to inject routes into the device RIB for traffic steering and traffic engineering.

Refer to the [gNxI](https://gnxi.srlinux.dev) page for details on each RPC.

## gNOI

When focusing on gNOI, it has a wide variety of RPCs to operate the device.

- [System](https://gnxi.srlinux.dev/gnoi/system) RPCs are used for actions like ping, traceroute and device reboot

- [File](https://gnxi.srlinux.dev/gnoi/file) service RPCs are used to transfer files to or from the device

- [OS](https://gnxi.srlinux.dev/gnoi/os) service RPCs are used for software image transfer and software upgrade

- [Healthz](https://gnxi.srlinux.dev/gnoi/healthz) service RPCs are used to obtain the health of hardware components

- [Factory Reset](https://gnxi.srlinux.dev/gnoi/factory_reset) RPCs are used to perform a factory reset of the device

- [Packet Link Qualification](https://gnxi.srlinux.dev/gnoi/packet_link_qualification) RPCs are used to check the health of a link

## gNOI OS Service

gNOI OS RPCs can be used to manage the software upgrade of a device.

The OS service supports the following RPCs:

- [Verify](https://gnxi.srlinux.dev/gnoi/os#VerifyRequest) RPC: to check the current software version running on the device

- [Install](https://gnxi.srlinux.dev/gnoi/os#InstallRequest) RPC: to transfer a software image to the device

- [Activate](https://gnxi.srlinux.dev/gnoi/os#ActivateRequest) RPC: to activate a software version on the device and optionally reboot the device to activate the new version

## Software upgrade procedure

Now let's use gNOI RPCs to perform a software upgrade of SR Linux.

### Device and version

Our device under test (DUT) is a 7220 IXR-H3 running SR Linux version `24.10.5` with a management IP of `10.0.1.204`.

```srl hl_lines="4 9"
A:admin@srlinux# show version
---------------------------------------------------------
Hostname             : srlinux
Chassis Type         : 7220 IXR-H3
Part Number          : 3HE16425AARA01
Serial Number        : NK222511561
System HW MAC Address: AC:8F:F8:70:0A:52
OS                   : SR Linux
Software Version     : v24.10.5
Build Number         : 344-g1c1a8d80ff4
Architecture         : x86_64
Last Booted          : 2025-12-03T04:55:56.926Z
Total Memory         : 32086031 kB
Free Memory          : 29913683 kB
---------------------------------------------------------
```

We will use [gNOIc](https://gnoic.kmrd.dev) as the gNOI client.

To install the client on a VM, run:

```bash
bash -c "$(curl -sL https://get-gnoic.kmrd.dev)"
```

To verify the gNOIc installation and version, run:

```bash
gnoic version
```

/// warning

A software upgrade cannot be executed on an SR Linux docker image in Containerlab. A physical device is required for this purpose.
///


### Enable gNOI service in SR Linux

gNOI service configuration is under gRPC. To simplify our process, we will use unencrypted (non-TLS) communication between gNOI client and the switch.

The gRPC configuration on our DUT is as follows:

```srl
set / system grpc-server mgmt admin-state enable
set / system grpc-server mgmt network-instance mgmt
set / system grpc-server mgmt services [ gnmi gnoi gnsi ]
```

This configuration allows all gNOI RPCs from the client. Optionally, you can also selectively enable specific gNOI services like gnoi.file.

### Check gNOI communication

Before we start the software upgrade process, let's verify the gNOI communication between the client and the switch.

We will use the gNOI System time RPC to get the current timestamp of the switch.

On the VM where the gnoic client is installed, run:

///tab | gNOIc command

```bash
gnoic -a 10.0.1.204 -u admin -p admin --insecure system time
```

///
///tab | Expected output

```bash
+------------------+-----------------------------------------+---------------------+
|   Target Name    |                  Time                   |      Timestamp      |
+------------------+-----------------------------------------+---------------------+
| 10.0.1.204:57400 | 2025-12-02 19:23:50.356281777 -0600 CST | 1764725030356281777 |
+------------------+-----------------------------------------+---------------------+
```

///

We have now verified the communication between the gNOIc client and the switch.

### Verify current software version

Now, let's verify the current software version running on the switch.

We will use the gNOI OS verify RPC for this purpose.

On the VM, run:

///tab | gNOIc command
```bash
gnoic -a 10.0.1.204 -u admin -p admin --insecure os verify
```

///
///tab | Expected output

```bash
+------------------+-------------+---------------------+
|   Target Name    |   Version   | Activation Fail Msg |
+------------------+-------------+---------------------+
| 10.0.1.204:57400 | 24.10.5-344 |                     |
+------------------+-------------+---------------------+
```

///

We verified that the current version is 24.10.5.

### Transfer new software image

Our objective is to upgrade the switch to SR Linux `25.10.1`.

The software image file is locally available on the VM.

We will use the gNOI OS Install RPC to transfer the image to the switch.

The Install RPC is a synchronous RPC that transfers the image in chunks and performs a checksum at the end of the transfer.

<!-- md:option type:info -->

:   !!! info
    Starting SR Linux 25.3, there is a rate limit applied by default for synchronous RPCs. Before attempting an OS Install RPC on versions 25.3 or later, increase the rate limit under `system grpc-server <name> rate-limit`.

On the VM, run:

///tab | gNOIc command

```bash
gnoic -a 10.0.1.204 -u admin -p admin --insecure os install --version srlinux_25.10.1-399 --pkg gnoi/srlinux-25.10.1-399.bin
```

///
/// tab | Expected output

```bash
INFO[0000] starting install RPC                         
INFO[0000] target "10.0.1.204:57400": starting Install stream 
INFO[0000] target "10.0.1.204:57400": TransferProgress bytes_received:5242880 
INFO[0000] target "10.0.1.204:57400": TransferProgress bytes_received:10485760 
<snip>
INFO[0029] target "10.0.1.204:57400": TransferProgress bytes_received:1599078400 
INFO[0029] target "10.0.1.204:57400": TransferProgress bytes_received:1604321280 
INFO[0029] target "10.0.1.204:57400": TransferProgress bytes_received:1609564160 
INFO[0029] target "10.0.1.204:57400": TransferProgress bytes_received:1614807040 
INFO[0029] target "10.0.1.204:57400": sending TransferEnd 
INFO[0029] target "10.0.1.204:57400": TransferProgress bytes_received:1620049920 
INFO[0029] target "10.0.1.204:57400": TransferContent done... 
```

///

### Taking a configuration backup

Before we activate the new software version, it is best practice to take a configuration backup and store it outside the switch.

We will use the gNOI File Get RPC for this purpose. This RPC will transfer the SR Linux configuration file to the VM under the `gnoi/config-24-10-backup` directory.

On the VM, run:

/// tab | gNOIc command

```bash
gnoic -a 10.0.1.204 -u admin -p admin --insecure file get --file /etc/opt/srlinux/config.json --dst gnoi/config-24-10-backup
```

///
/// tab | Expected output

```bash
INFO[0000] "10.0.1.204:57400" received 64000 bytes      
INFO[0000] "10.0.1.204:57400" received 18171 bytes      
INFO[0000] "10.0.1.204:57400" file "/etc/opt/srlinux/config.json" saved 
```

///
/// tab | Check on VM

```bash
ls -lrt gnoi/config-24-10-backup/etc/opt/srlinux/config.json
```

///
/// tab | Expected output

```bash
-rw-r--r-- 1 root root 82171 Dec  9 22:23 gnoi/config-24-10-backup/etc/opt/srlinux/config.json
```

///

### Activate new software version

After successfully transferring the software image, we can proceed to activate the software image.

We will use the gNOI OS Activate RPC for this purpose.

<!-- md:option type:info -->

:   !!! info
    By default, the Activate RPC will perform a reboot of the device to activate the new software. To avoid a reboot during activation (and perform reboot at a later time), use the `--no-reboot` flag in the gnoic command.

Run the following command to activate the new software with a device reboot.

/// tab | gNOIc command

```bash
gnoic -a 10.0.1.204 -u admin -p admin --insecure os activate --version 25.10.1-399
```

///
/// tab | Expected output

```bash
INFO[0004] target "10.0.1.204:57400" activate response "activate_ok:{}" 
```

///

### Verify software version

After the device boots up successfully, verify the current software version of the device and confirm that the software upgrade was a success.

///tab | gNOIc command
```bash
gnoic -a 10.0.1.204 -u admin -p admin --insecure os verify
```

///
///tab | Expected output

```bash
+------------------+-------------+---------------------+
|   Target Name    |   Version   | Activation Fail Msg |
+------------------+-------------+---------------------+
| 10.0.1.204:57400 | 25.10.1-399 |                     |
+------------------+-------------+---------------------+
```

///

<!-- md:option type:success -->

:   !!! success
        We have successfully upgraded the device to 25.10

## Software downgrade procedure

The downgrade procedure is similar to the upgrade process using the same gNOI OS RPCs.

For our example, we will downgrade to our original version `24.10.5`.

### Restore configuration backup

Before downgrading the device, it is important to restore the original configuration from `24.10.5`.

We will use gNOI File Put RPC to transfer the configuration backup available on the VM to the switch. The file will be transferred to the `/tmp` directory. The file can then be copied over to overwrite the `/etc/opt/srlinux/config.json` file.

/// tab | gNOIc command

```bash
gnoic -a 10.0.1.204 -u admin -p admin --insecure file put --file gnoi/config-24-10-backup/etc/opt/srlinux/config.json --dst /tmp/config.json
```

///
/// tab | Expected output

```bash
INFO[0000] "10.0.1.204:57400" sending file="gnoi/config-24-10-backup/etc/opt/srlinux/config.json" hash 
INFO[0000] "10.0.1.204:57400" file "gnoi/config-24-10-backup/etc/opt/srlinux/config.json" written successfully 
```

///

Log in to the switch and run the below command to overwrite the default configuration file with the backup.

```bash
bash cp /tmp/config.json /etc/opt/srlinux/config.json
```

### Transfer software image

If the device is being downgraded to a different software release, transfer the image using the previously mentioned example.

### Activate the downgrade

We will use the same gNOI OS Activate RPC.

On the VM, run:

/// tab | gNOIc command

```bash
gnoic -a 10.0.1.204 -u admin -p admin --insecure os activate --version 24.10.5-344
```

///
/// tab | Expected output

```bash
INFO[0003] target "10.0.1.204:57400" activate response "activate_ok:{}" 
```

///

### Verify the current version

///tab | gNOIc command
```bash
gnoic -a 10.0.1.204 -u admin -p admin --insecure os verify
```

///
///tab | Expected output

```bash
+------------------+-------------+---------------------+
|   Target Name    |   Version   | Activation Fail Msg |
+------------------+-------------+---------------------+
| 10.0.1.204:57400 | 24.10.5-344 |                     |
+------------------+-------------+---------------------+
```

///

<!-- md:option type:success -->

:   !!! success
        We have successfully downgraded the device to 24.10.5

## Summary

Software upgrade automation is not an easy task. In this article, we showcased how modern tools like gRPC can be used to simplify and automate a software upgrade process from a remote client.