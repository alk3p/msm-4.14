#include <linux/module.h>

int is_fod;

MODULE_PARM_DESC(is_fod, "Activate FOD fix");
module_param_named(is_fod, is_fod, int, 0644);
