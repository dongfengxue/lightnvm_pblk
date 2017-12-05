#
# Makefile for Open-Channel SSDs.
#

KERNEL_VER ?= $(shell uname -r)
KERNEL_DIR:=/lib/modules/$(KERNEL_VER)/build
PWD:=$(shell pwd)

CONFIG_NVM:=M
CONFIG_NEM_RPPC:=M
CONFIG_NVM_PBLK:=M

obj-$(CONFIG_NVM)		:= core.o
obj-$(CONFIG_NVM_RRPC)		+= rrpc.o
obj-$(CONFIG_NVM_PBLK)		+= pblk.o
pblk-y				:= pblk-init.o pblk-core.o pblk-rb.o \
				   pblk-write.o pblk-cache.o pblk-read.o \
				   pblk-gc.o pblk-recovery.o pblk-map.o \
				   pblk-rl.o pblk-sysfs.o
#add by lhj

pblk:
	make -C $(KERNEL_DIR) M=$(PWD) modules
clean:
	make -C $(KERNEL_DIR) M=$(PWD) clean
	#rm -rf *.o *.mod.c *.ko *.symvers *.order *.unsigned .*.cmd .tmp_versions pblk.ko.digest*
