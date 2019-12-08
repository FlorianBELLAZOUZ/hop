;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/hopscript/expanders.scm             */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Wed Aug 23 08:18:53 2017                          */
;*    Last change :  Sat Dec  7 06:30:58 2019 (serrano)                */
;*    Copyright   :  2017-19 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    HopScript expanders                                              */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __hopscript_expanders

   (library hop)
   
   (include "property_expd.sch"
	    "arithmetic.sch"
	    "array.sch"
	    "number.sch"
	    "call.sch"
	    "function.sch"
	    "arguments.sch"
	    "public_expd.sch"
	    "stringliteral_expd.sch"
	    "types_expd.sch"
	    "constants_expd.sch"
	    "names_expd.sch"
	    "expanders.sch")

   (import  __hopscript_types
	    __hopscript_object
	    __hopscript_error
	    __hopscript_private
	    __hopscript_public
	    __hopscript_worker
	    __hopscript_pair
	    __hopscript_obj
	    __hopscript_function
	    __hopscript_lib
	    __hopscript_property
	    __hopscript_stringliteral)

   (export  (hopscript-install-expanders!)))


