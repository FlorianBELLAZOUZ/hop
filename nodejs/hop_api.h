/*=====================================================================*/
/*    serrano/prgm/project/hop/hop/nodejs/hop_api.h                    */
/*    -------------------------------------------------------------    */
/*    Author      :  Manuel Serrano                                    */
/*    Creation    :  Fri Feb 24 15:38:53 2023                          */
/*    Last change :  Fri Mar  3 07:25:59 2023 (serrano)                */
/*    Copyright   :  2023 Manuel Serrano                               */
/*    -------------------------------------------------------------    */
/*    Hop Specific macro redefinitions                                 */
/*=====================================================================*/
#ifndef HOP_NODE_API_H_
#define HOP_NODE_API_H_

#include <stdarg.h>

/*---------------------------------------------------------------------*/
/*    Imports                                                          */
/*---------------------------------------------------------------------*/
extern int bgl_napi_typeof(obj_t, obj_t);

extern obj_t bgl_napi_create_string_utf8(obj_t, obj_t);
extern obj_t bgl_napi_create_function(obj_t, obj_t, obj_t);
extern obj_t bgl_napi_create_object(obj_t);
extern obj_t bgl_napi_create_array(obj_t);
extern obj_t bgl_napi_create_promise(obj_t, obj_t);

extern obj_t bgl_napi_get_element(obj_t, obj_t, int);
extern obj_t bgl_napi_set_element(obj_t, obj_t, int, obj_t);
extern obj_t bgl_napi_get_named_property(obj_t, obj_t, obj_t);
extern obj_t bgl_napi_put_named_property(obj_t, obj_t, obj_t, obj_t);
extern obj_t bgl_napi_define_property(napi_env _this, obj_t this, obj_t prop, obj_t met);
extern napi_status napi_define_properties(napi_env _this, napi_value this, size_t count, const napi_property_descriptor *properties);

extern napi_status napi_get_cb_info(napi_env _this, napi_callback_info info, size_t *argc, napi_value *argv, napi_value *this_arg, void **data);
extern obj_t bgl_napi_call_function(napi_env _this, obj_t this, obj_t fun, size_t argc, napi_value *argv);
extern obj_t bgl_napi_call_function_res(napi_env _this, obj_t this, obj_t fun, size_t argc, napi_value *argv, napi_value *res);

/*---------------------------------------------------------------------*/
/*    bgl_napi_async_work                                              */
/*---------------------------------------------------------------------*/
struct napi_async_work__ {
   pthread_t pthread;
   obj_t env;
   napi_async_execute_callback execute;
   napi_async_complete_callback complete;
   void *data;
   char started;
};
   
/*---------------------------------------------------------------------*/
/*    Module init                                                      */
/*---------------------------------------------------------------------*/
#undef NAPI_C_CTOR
#undef NAPI_MODULE_X
#undef NAPI_MODULE

#define NAPI_C_CTOR(modname)						\
   static obj_t BGl_z62hopscriptz62zz ## modname ## z00(obj_t env, obj_t _this, obj_t this, obj_t scope, obj_t module) { \
     napi_status status; \
     napi_value result; \
     obj_t nexports; \
     status = napi_get_named_property(_this, module, "exports", &result); \
     nexports = _module.nm_register_func(_this, result); \
     napi_put_named_property(_this, module, "exports", nexports, &result); \
     return nexports; \
   } \
   DEFINE_EXPORT_BGL_PROCEDURE(BGl_hopscriptzd2envzd2zz ## modname ## z00, __BGl_z62hopscriptz62zz ## modname ## z00, BGl_z62hopscriptz62zz ## modname ## z00, 0L, BUNSPEC, 4); \
   obj_t bigloo_dlopen_init() { \
     obj_t res = BTRUE; \
     BGL_MVALUES_NUMBER_SET(2); \
     BGL_MVALUES_VAL_SET(1,string_to_bstring(# modname)); \
     return res; \
  } \
  static void _register_ ## modname(void)

#define NAPI_MODULE_X(modname, regfunc, priv, flags)                  \
  EXTERN_C_START                                                      \
    static napi_module _module =                                      \
    {                                                                 \
      NAPI_MODULE_VERSION,                                            \
      flags,                                                          \
      __FILE__,                                                       \
      regfunc,                                                        \
      #modname,                                                       \
      priv,                                                           \
      {0},                                                            \
    };                                                                \
  NAPI_C_CTOR(modname) {				              \
      napi_module_register(&_module);                                 \
    }                                                                 \
  EXTERN_C_END

#define NAPI_MODULE(modname, regfunc)                                 \
  NAPI_MODULE_X(modname, regfunc, NULL, 0)  // NOLINT (readability/null_usage)

/*---------------------------------------------------------------------*/
/*    Wrappers                                                         */
/*---------------------------------------------------------------------*/
#define napi_create_string_utf8(_this, string, sz, res) \
  (*res = bgl_napi_create_string_utf8(_this, string_to_bstring(string)), napi_ok)

#define napi_create_double(_this, val, res) \
   (*res = DOUBLE_TO_REAL(val), napi_ok)

#define napi_create_int32(_this, val, res) \
   (*res = BINT(val), napi_ok)

#define napi_create_uint32(_this, val, res) \
   (*res = BINT(val), napi_ok)

#define napi_create_object(_this, res) \
   (*res = bgl_napi_create_object(_this), napi_ok)

#define napi_create_array(_this, res) \
  (*res = bgl_napi_create_array(_this), napi_ok)

#define napi_create_promise(_this, deferred, res) \
  (*res = bgl_napi_create_promise(_this, (obj_t)deferred), napi_ok)

#define napi_resolve_deferred(_this, deferred, value) \
  (bgl_napi_call_function(_this, BUNSPEC, CAR(deferred), 1, &value), napi_ok)
  
#define napi_reject_deferred(_this, deferred, value) \
  (bgl_napi_call_function(_this, BUNSPEC, CDR(deferred), 1, &value), napi_ok)
  
#define napi_get_named_property(_this, this, prop, res) \
  (*res = bgl_napi_get_named_property(_this, this, string_to_bstring(prop)), napi_ok)

#define napi_put_named_property(_this, this, prop, val, res) \
  (*res = bgl_napi_put_named_property(_this, this, string_to_bstring(prop), val), napi_ok)

#define napi_set_named_property(_this, this, prop, val) \
  (bgl_napi_put_named_property(_this, this, string_to_bstring(prop), val), napi_ok)

#define napi_get_undefined(env, res) \
  (*res = BUNSPEC, napi_ok)
  
#define napi_get_element(_this, this, index, res) \
  (*res = bgl_napi_get_element(_this, this, index), napi_ok)

#define napi_set_element(_this, this, index, val) \
  (bgl_napi_set_element(_this, this, index, val), napi_ok)

#define napi_get_global(_this, res) \
  (*res = _this, napi_ok)

#define napi_call_function(_this, global, fun, argc, argv, res) \
  bgl_napi_call_function_res(_this, global, fun, argc, argv, res)

#define napi_typeof(_this, val, res) \
  (*res = (napi_valuetype)bgl_napi_typeof(_this, val), napi_ok)

#define napi_get_value_double(_this, val, res) \
  (INTEGERP(val) \
   ? (*res = (double)CINT(val), napi_ok) \
   : REALP(val) \
   ? (*res = REAL_TO_DOUBLE(val), napi_ok) \
   : napi_number_expected)
#endif

#define napi_delete_async_work(env, work) \
  (free(work), napi_ok)
