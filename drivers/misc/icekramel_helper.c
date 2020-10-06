// SPDX-License-Identifier: GPL-2.0

#define pr_fmt(fmt) "icekramel_helper: " fmt

#include <linux/cpu.h>
#include <linux/module.h>
#include <linux/sysctl.h>

static DEFINE_MUTEX(ps_mutex);

static struct ctl_table_header *ops_table_header;
static int zero = 0, two = 2;

int is_doze = 0;
unsigned int remove_op_capacity = 0;

static void __do_cpu_updown(bool up)
{
	int cpu;

	for_each_possible_cpu(cpu) {
		if (!cpumask_test_cpu(cpu, cpu_lp_mask)) {
			if (up)
				cpu_up(cpu);
			else
				cpu_down(cpu);
		}
	}
}

static void _set_offline(int type)
{
	switch (type) {
		case 0:
			__do_cpu_updown(true);
			pr_info("core_ctl: All clusters booted");
			break;
		case 1:
			__do_cpu_updown(false);
			pr_info("core_ctl: Doze mode on");
			break;
		case 2:
			__do_cpu_updown(false);
			cpu_up(4);
			pr_info("core_ctl: cpu4 booted for fp service");
			break;
		default:
			return;
	}
}

static bool verify_mode_param(int type)
{
	return type >= 0 && type <= 2;
}

int offline_handler(struct ctl_table *table, int write,
		void __user *buffer, size_t *lenp,
		loff_t *ppos)
{
	int ret;
	unsigned int *data = (unsigned int *)table->data;

	mutex_lock(&ps_mutex);

	ret = proc_dointvec_minmax(table, write, buffer, lenp, ppos);

	if (ret || !write)
		goto done;

	if (verify_mode_param(*data))
		_set_offline(*data);
	else
		ret = -EINVAL;

done:
	mutex_unlock(&ps_mutex);
	return ret;
}

// static struct ctl_table ops_table[];
static struct ctl_table ops_table[] = {
	{
		.procname	= "doze_mode",
		.data		= &is_doze,
		.maxlen		= sizeof(signed int),
		.mode		= 0666,
		.proc_handler	= offline_handler,
		.extra1		= &zero,
		.extra2		= &two,
	},
	{ }
};

static struct ctl_table sysctl_custom_table[] = {
	{
		.procname	= "kernel",
		.mode		= 0555,
		.child		= ops_table,
	},
	{ }
};

static int __init helper_init(void)
{
	ops_table_header = register_sysctl_table(sysctl_custom_table);
	return 0;
}

static __exit void helper_exit(void)
{
	unregister_sysctl_table(ops_table_header);
	return;
}

subsys_initcall(helper_init);
module_exit(helper_exit);

MODULE_PARM_DESC(is_custombatt, "Remove battery capacity limit");
module_param_named(is_custombatt, remove_op_capacity, uint, 0444);
