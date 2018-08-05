# -*- coding: iso-8859-1 -*-

import re
import sys
import os
import time
import string
from StringIO import StringIO

output_inc_path = "../src/domsuspendcallback.inc"

def fatal(msg):
    print >>sys.stderr, msg
    time.sleep(1)
    sys.exit(1)

class FunctorGenerator:
	def __init__(self):
		return

	def generate_functors(self, max_arguments):
		try:
			output = open(output_inc_path, "w")
		except:
			fatal("Can't open \"%s\" for writing." % output_inc_path)

		function_object_template = string.Template("""
template<class ObjectType${comma_if_needed}${templ_arg_list}>
class OpMemberFunctionObject${num_args} : public OpFunctionObjectBase
{
public:
	typedef void(ObjectType::*MethodType)(${fun_arg_list});
	OpMemberFunctionObject${num_args}(ObjectType* object, MethodType method${comma_if_needed}${fun_arg_list}) : m_object(object), m_method(method)${comma_if_needed}${constructor_initializer_list} {}
	virtual void Call() { (m_object->*m_method)(${call_arg_list}); }
private:
	ObjectType* m_object;
	MethodType m_method;
${member_list}};
""")

		print >> output, "/* This file is autogenerated using ***%s*** script */"%os.path.basename(sys.argv[0])
		for i in range(0, max_arguments + 1):
			templ_arg_list = ""
			for j in range(1, i + 1):
				templ_arg_list = templ_arg_list + "typename arg%dtype, "%j
			templ_arg_list = templ_arg_list[0:len(templ_arg_list)-2]

			fun_arg_list = ""
			for j in range(1, i + 1):
				fun_arg_list = fun_arg_list + "arg%dtype arg%d, "%(j,j)
			fun_arg_list = fun_arg_list[0:len(fun_arg_list)-2]

			call_arg_list = ""
			for j in range(1, i + 1):
				call_arg_list = call_arg_list + "m_arg%d, "%j
			call_arg_list = call_arg_list[0:len(call_arg_list)-2]

			member_list = ""
			for j in range(1, i + 1):
				member_list = member_list + "\targ%dtype m_arg%d;\n"%(j,j)

			constructor_initializer_list = ""
			for j in range(1, i + 1):
				constructor_initializer_list = constructor_initializer_list + "m_arg%d(arg%d), "%(j,j)
			constructor_initializer_list = constructor_initializer_list[0:len(constructor_initializer_list)-2]

			comma_if_needed = ", " if (i > 0) else ""

			kw_map = {"num_args":i, "templ_arg_list":templ_arg_list, "fun_arg_list":fun_arg_list, "call_arg_list":call_arg_list, "comma_if_needed":comma_if_needed, "constructor_initializer_list":constructor_initializer_list, "member_list":member_list}

			print >> output, function_object_template.substitute(kw_map)


generator = FunctorGenerator()
generator.generate_functors(5)