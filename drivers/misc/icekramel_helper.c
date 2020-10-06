#include <linux/module.h>

int is_fod;

MODULE_PARM_DESC(is_fod, "Activate FOD fix");
module_param_named(is_fod, is_fod, int, 0644);

unsigned int remove_op_capacity;

MODULE_PARM_DESC(is_custombatt, "Remove battery capacity limit");
module_param_named(is_custombatt, remove_op_capacity, uint, 0444);
