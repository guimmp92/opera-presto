/* -*- Mode: pike; tab-width: 4; indent-tabs-mode: t; c-basic-offset: 4; -*-
 *
 * Copyright (C) 2005 Opera Software AS.  All rights reserved.
 *
 * This file is part of the Opera web browser.  It may not be distributed
 * under any circumstances.
 * This program generates the internal enum tables used in
 * string<->enum lookups
 */

constant TEMP_FILE = "_enum_file_.tmp";
constant INPUT_FILE = "../src/enums.txt";
constant SOURCE_FILENAME = "../src/SVGInternalEnumTables.cpp";
constant HEADER_FILENAME = "../src/SVGInternalEnumTables.h";
constant SELFTEST_TABLE_FILENAME = "../selftest/svg_enums.txt";
constant SELFTEST_FILENAME = "../selftest/svg.enums.ot";
constant FILE_HEADER = #"/* -*- Mode: c++; tab-width: 4; indent-tabs-mode: t; c-basic-offset: 4; c-file-style: \"stroustrup\" -*-
**
** Copyright (C) 2005 Opera Software AS.  All rights reserved.
**
** This file is part of the Opera web browser.  It may not be distributed
** under any circumstances.
**
** THIS FILE IS AUTO-GENERATED BY A SCRIPT. DO NOT EDIT THIS FILE DIRECTLY!
*/

";
constant SELFTEST_FILE_HEADER = #"/* -*- mode: c++; tab-width: 4; indent-tabs-mode: t; c-basic-offset: 4; c-file-style: \"stroustrup\" -*-
 *
 * THIS FILE IS AUTO-GENERATED BY A SCRIPT. DO NOT EDIT THIS FILE DIRECTLY!
 */
";
constant DEFINES = #"
#if !defined(HAS_COMPLEX_GLOBALS)
# define SVG_ENUMS_START void init_g_svg_enum_entries() { SVGEnumEntry* local = g_svg_enum_entries; int i=0;
# define SVG_ENUMS_ENTRY(val1, val2, val3, val4) if (local){ local[i].type = val1;local[i].val = val2;local[i].str = val3; local[i].str_len = val4;} i++;
# define SVG_ENUMS_END SVG_ENUMS_ENTRY(SVGENUM_UNKNOWN, 0, NULL, 0) }
#else
# define SVG_ENUMS_START const SVGEnumEntry g_svg_enum_entries[] = {
# define SVG_ENUMS_ENTRY(type, val, str, len) {type, val, str, len},
# define SVG_ENUMS_END { SVGENUM_UNKNOWN, 0, NULL, 0 } };
extern const SVGEnumEntry g_svg_enum_entries[];
#endif // !HAS_COMPLEX_GLOBALS
";
constant SECTION_MARKER = "@@";
constant USAGE = "Usage: modules/svg/src$ pike ../scripts/enums.pike\n";

constant ENUM_FILTER_ALL = 1;
constant ENUM_FILTER_NO_SPECIAL = 2;

int first = 0;

int(0..1) equal_files(string fn1, string fn2)
{
	string content1 = Stdio.read_file(fn1);
	string content2 = Stdio.read_file(fn2);

	/* Two non-existing files are not equal */
	if (content1 && content2)
	{
		string hash_1 = MIME.encode_base64(Crypto.SHA1.hash(content1));
		string hash_2 = MIME.encode_base64(Crypto.SHA1.hash(content2));
		return (hash_1 == hash_2);
	}
	else
		return 0;
}

Stdio.File get_temp_file()
{
	return Stdio.File(TEMP_FILE, "tcw");
}

void commit_temp_file(Stdio.File file, string out_file_name)
{
	if (!file->is_open())
		file->close();

	write("%s: ", out_file_name);

	if (!equal_files(TEMP_FILE, out_file_name))
	{
		write("Writing new version... \n");
		Stdio.cp(TEMP_FILE, out_file_name);
	}
	else
	{
		write("Leaving untouched\n");
	}
	Filesystem.System()->rm(TEMP_FILE);
}

array get_special_enum_types(array rows)
{
	function get_type_name = lambda (mapping a) { return (string)a["enum_type"]; };
	function filter_special = lambda(mapping a) { return !a["enum_val"]; };
	return Array.uniq(Array.map(Array.filter(rows, filter_special),	get_type_name));
}

void enum_map(array(mapping) rows, function action, int|void filter)
{
	array special_enum_types = get_special_enum_types(rows);
	array defines = ({});

	if (filter == 0)
		filter = ENUM_FILTER_ALL;

	foreach(rows; int i; mapping row)
	{
		defines -= row["sub_defines"];
		defines += row["add_defines"];

		string sub = "";
		foreach(row["sub_defines"], Parser.C.Token define)
			sub += sprintf("#endif // %s\n", strip_define((string)define));

		string add = "";
		foreach(row["add_defines"], Parser.C.Token define)
			add += sprintf("#%s\n", define);

		if (!(filter == ENUM_FILTER_NO_SPECIAL &&
			  sizeof(({ (string)row["enum_type"] }) & special_enum_types) > 0))
		{
			action(row, defines, add, sub);
		}
	}

	string sub = "";
	foreach(defines, Parser.C.Token define)
		sub += sprintf("#endif // %s\n", strip_define((string)define));
	action(0, defines, "", sub);
}

string strip_define(string define)
{
	return define - "ifdef " - " ifndef " - "if ";
}

string get_include_section(array(string) input_file)
{
	string res = "";
	int section = 0;
	for(int i=0;i<sizeof(input_file); ++i)
	{
		string line = input_file[i];
		if (line == SECTION_MARKER)
		{
			section++;
			continue;
		}

		if (section == 1)
			res += line + "\n";
	}

	return res;
}

array get_rows(array(string) input_file)
{
	array rows = ({});
	array defines = ({});
	int section = 0;
	
	for(int i=0;i<sizeof(input_file); ++i)
	{
		string line = input_file[i];

		if (!line || sizeof(line) == 0)
			continue;

		if (has_prefix(String.trim_whites(line), "//"))
			continue;

		if (line == SECTION_MARKER)
		{
			section++;
			continue;
		}

		if (section != 2)
			continue;

		array(Parser.C.Token|array) toks;
		mixed exc = catch {
				array(string) line_split = Parser.C.split(line);
				array(Parser.C.Token) line_tokens = Parser.C.tokenize(line_split);
				array trimmed_line_tokens = Parser.C.hide_whitespaces(line_tokens);
				toks = Parser.C.group(trimmed_line_tokens);
			};

		if (exc == 0)
		{
			mapping row = ([]);
			array line_defines = ({});

			int i=0;
			if (i < sizeof(toks))
				row["enum_type"] = toks[i++];
			while (i < sizeof(toks))
			{
				if (arrayp(toks[i]))
				{
					array expr = toks[i++];
					int i;
					while(i<sizeof(expr))
					{
						if (expr[i] == "{" || expr[i] == "}" )
						{
							i++;
							continue;
						}
							
						array(Parser.C.Token) exprtokens = ({});
						while (i < sizeof(expr) && expr[i] != "," && expr[i] != "}")
							exprtokens += ({ expr[i++] });
							
						line_defines += ({ Parser.C.simple_reconstitute(exprtokens) });
						i++;
					}
				}
				else if (i + 1 < sizeof(toks))
				{
					row["enum_val"] = toks[i++];
					row["enum_string"] = toks[i++];
				}
				else
					i++;
			}

			row["add_defines"] = line_defines - defines;
			row["sub_defines"] = defines - line_defines;
			defines = line_defines;
			rows += ({ row });
		}
	}

	return rows;
}

void write_enum_header(array rows)
{
	Stdio.File of = get_temp_file();
	if (!of)
	{
		werror("Couldn't open temporary output file!\n");
		return;
	}

	of->write(FILE_HEADER);
	of->write("#ifndef SVG_INTERNAL_ENUM_TABLES_H\n");
	of->write("#define SVG_INTERNAL_ENUM_TABLES_H\n");
	of->write("#ifdef SVG_SUPPORT\n");
	of->write("\n");
	of->write("extern const int svg_enum_lookup[];\n\n");
	of->write("enum SVGEnumType\n{\n");
	multiset found_enum_types = (<>);

	enum_map(rows, lambda(mapping row, array defines, string add, string sub) {
					   if (row)
					   {
						   of->write("%s", sub);
						   of->write("%s", add);

						   string enum_type = (string)row["enum_type"];
						   if (found_enum_types[enum_type] == 0)
						   {
							   of->write("\t%s,\n", enum_type);
							   found_enum_types[enum_type] = 1;
						   }
					   }
					   else
					   {
						   of->write("%s", sub);
					   }
				   });

	of->write("\n\tSVGENUM_TYPE_COUNT\n");
	of->write("};\n\n");

	int dummy_i;
	found_enum_types = (<>);
	of->write("enum SVGEnumTypeIndexes\n{\n");
	enum_map(rows, lambda(mapping row, array defines, string add, string sub) {
					   if (row)
					   {
						   of->write("%s", sub);
						   of->write("%s", add);

						   string enum_type = (string)row["enum_type"];
						   if (found_enum_types[enum_type] == 0)
						   {
							   of->write("\tSVG_ENUM_IDX_%s,\n", enum_type);
							   found_enum_types[enum_type] = 1;
						   }
						   else
						   {
							   of->write("\tSVG_ENUM_DUMMY_%d,\n", dummy_i++);
						   }
					   }
					   else
					   {
						   of->write("%s", sub);
					   }
				   }, ENUM_FILTER_NO_SPECIAL);

	of->write("\n\tSVG_ENUM_ENTRIES_COUNT\n");
	of->write("};\n\n");

	of->write("struct SVGEnumEntry\n{\n");
	of->write("\t SVGEnumType type;\n");
	of->write("\t int val;\n");
	of->write("\t const char* str;\n");
	of->write("\t size_t str_len;\n");
	of->write("};\n");
	of->write(DEFINES);
	of->write("\n#endif // SVG_SUPPORT\n");
	of->write("#endif // SVG_INTERNAL_ENUM_TABLES_H\n");

	commit_temp_file(of, HEADER_FILENAME);
}

void write_enum_source(array rows, string include)
{
	Stdio.File of = get_temp_file();

	if (!of)
	{
		werror("Couldn't open temporary output file!\n");
		return;
	}

	of->write(FILE_HEADER);
	of->write("#include \"core/pch.h\"\n\n");
	of->write("#ifdef SVG_SUPPORT\n\n");
	of->write("#include \"modules/svg/src/svgpch.h\"\n");
	of->write("#include \"modules/svg/src/SVGInternalEnum.h\"\n");
	of->write("#include \"modules/svg/src/SVGInternalEnumTables.h\"\n");
	of->write("#include \"modules/svg/src/SVGManagerImpl.h\"\n\n");
	of->write(include);
	of->write("\n");
	of->write("#ifdef _DEBUG\n");
	of->write("CONST_ARRAY(g_svg_enum_type_strings, char*)\n");
	multiset found_enum_types = (<>);
	
	first = 1;
	enum_map(rows, lambda(mapping row, array defines, string add, string sub) {
					   if (row)
					   {
						   string enum_type = (string)row["enum_type"];
						   if (found_enum_types[enum_type] == 0)
						   {
							   if(first)
							   {
									of->write("%s", sub);
								    of->write("%s", add);
									of->write("\tCONST_ENTRY(\"%s\")", enum_type);
									first = 0;
							   }
							   else
							   {
									of->write(",\n");
									of->write("%s", sub);
								    of->write("%s", add);
									of->write("\tCONST_ENTRY(\"%s\")", enum_type);
							   }
							   found_enum_types[enum_type] = 1;
						   }
					   }
					   else
					   {
							of->write("%s", sub);
					   }
				   }, ENUM_FILTER_ALL);
	of->write("\nCONST_END(g_svg_enum_type_strings)\n\n");

	of->write("CONST_ARRAY(g_svg_enum_name_strings, char*)\n");
	
	first = 1;
	enum_map(rows, lambda(mapping row, array defines, string add, string sub) {
					   if (row)
					   {
						   if(first)
						   {
							   of->write("%s", sub);
							   of->write("%s", add);
							   of->write("\tCONST_ENTRY(\"%s\")", row["enum_val"]);
							   first = 0;
						   }
						   else
						   {
						   	   of->write(",\n");
						   	   of->write("%s", sub);
							   of->write("%s", add);
							   of->write("\tCONST_ENTRY(\"%s\")", row["enum_val"]);
						   }
					   }
					   else
					   {
							of->write("%s", sub);
					   }
				   }, ENUM_FILTER_NO_SPECIAL);
	of->write("\nCONST_END(g_svg_enum_name_strings)\n\n");
	of->write("#endif // _DEBUG\n\n");
	
	of->write("const int svg_enum_lookup[] = {\n");
	found_enum_types = (<>);
	enum_map(rows, lambda(mapping row, array defines, string add, string sub) {
					   if (row)
					   {
						   of->write("%s", sub);
						   of->write("%s", add);

						   string enum_type = (string)row["enum_type"];
						   if (found_enum_types[enum_type] == 0)
						   {
							   if (row["enum_val"])
								   of->write("\tSVG_ENUM_IDX_%s,\n", enum_type);
							   else
								   of->write("\t-1,\n");

							   found_enum_types[enum_type] = 1;
						   }
					   }
					   else
					   {
						   of->write("%s", sub);
					   }
				   });

	of->write("};\n\n");

	of->write("SVG_ENUMS_START\n");
	enum_map(rows, lambda(mapping row, array defines, string add, string sub) {
					   if (row)
					   {
						   of->write("%s", sub);
						   of->write("%s", add);
						   of->write("\tSVG_ENUMS_ENTRY(%s, %s, %s, %d)\n",
									 row["enum_type"], row["enum_val"],
									 row["enum_string"],
									 sizeof((string)row["enum_string"]) - 2);
					   }
					   else
					   {
						   of->write("%s", sub);
					   }}, ENUM_FILTER_NO_SPECIAL);
	of->write("SVG_ENUMS_END\n\n");
	of->write("#endif // SVG_SUPPORT\n");

	commit_temp_file(of, SOURCE_FILENAME);
}

void write_selftest_file(array(mapping) rows)
{
	Stdio.File of = get_temp_file();

	if (!of)
	{
		werror("Couldn't open temporary output file!\n");
		return 0;
	}

	of->write(SELFTEST_FILE_HEADER);

	of->write("group \"svg.enums\";\n");
	of->write("require SVG_SUPPORT;\n");
	of->write("\ninclude \"modules/svg/src/SVGInternalEnum.h\";\n\n");

	enum_map(rows, lambda(mapping|void row, array defines, string add, string sub) {
					   if (row)
					   {
						   of->write("test(\"Enum to string '%s::%s'\")\n", row["enum_type"], row["enum_val"]);
						   foreach(defines, string define)
							   of->write("\t\trequire %s;\n", strip_define(define));
						   of->write("{\n");
						   of->write("\tconst char* string_rep = SVGEnumUtils::GetEnumName(%s, %s);\n",
									 row["enum_type"], row["enum_val"]);
						   of->write("\tverify(string_rep);\n");
						   of->write("\tverify(op_strcmp(string_rep, %s) == 0);\n", row["enum_string"]);
						   of->write("}\n");
					   }
				   }, ENUM_FILTER_NO_SPECIAL);

	enum_map(rows, lambda(mapping|void row, array defines, string add, string sub) {
					   if (row)
					   {
						   of->write("test(\"String to enum '%s::%s'\")\n", row["enum_type"], row["enum_val"]);
						   foreach(defines, string define)
							   of->write("\t\trequire %s;\n", strip_define(define));
						   of->write("{\n");
						   of->write("\tint int_val = SVGEnumUtils::GetEnumValue(%s, UNI_L(%s), %d);\n",
									 row["enum_type"],
									 row["enum_string"],
									 sizeof((string)row["enum_string"]) - 2);
						   of->write("\tverify(int_val != -1);\n");
						   of->write("\tverify(int_val == %s);\n",
									 row["enum_val"]);
						   of->write("}\n");
					   }
				   }, ENUM_FILTER_NO_SPECIAL);

	commit_temp_file(of, SELFTEST_FILENAME);
}

int main(int argc, array(string) argv)
{
	if (argc > 1)
	{
		werror(USAGE);
		return 1;
	}

	

	if (Filesystem.System()->stat(INPUT_FILE))
	{
		array(string) input_file = ({});
		Stdio.FILE file = Stdio.FILE(INPUT_FILE);

		if (!file)
		{
			werror(USAGE);
			werror("Couldn't open input file!\n");
			return 1;
		}

		object iter = file->line_iterator(1);
		while(iter)
		{
			string row = iter->value();
			input_file += ({ row });
			iter->next();
		}
		file->close();

		string include = get_include_section(input_file);
		array enum_rows = get_rows(input_file);

		write_enum_header(enum_rows);
		write_enum_source(enum_rows, include);
		write_selftest_file(enum_rows);

#if __NT__
		sleep(3.0); // Sleep a while so that we can se the result.
#endif // __NT__
	}
	else
	{
		werror(USAGE);
		werror("Couldn't open input file!\n");
		return 1;
	}
}