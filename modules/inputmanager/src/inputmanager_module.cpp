/* -*- Mode: c++; indent-tabs-mode: nil; c-file-style: "gnu" -*-
 *
 * Copyright (C) 1995-2009 Opera Software ASA.  All rights reserved.
 *
 * This file is part of the Opera web browser.  It may not be distributed
 * under any circumstances.
 */

#include "core/pch.h"

#include "modules/inputmanager/inputmanager_module.h"
#include "modules/inputmanager/inputmanager.h"

void InputmanagerModule::InitL(const OperaInitInfo &info)
{
	m_input_manager = OP_NEW_L(OpInputManager, ());
	LEAVE_IF_ERROR(m_input_manager->Construct());

#ifndef HAS_COMPLEX_GLOBALS
	// The list of action strings is generated by the hardcore module,
	// but since we are the client, we run the initializer and own
	// the array.
	extern void init_s_action_strings();
	init_s_action_strings();
#endif // !HAS_COMPLEX_GLOBALS
}

void InputmanagerModule::Destroy()
{
	OP_DELETE(m_input_manager);
	m_input_manager = NULL;
}