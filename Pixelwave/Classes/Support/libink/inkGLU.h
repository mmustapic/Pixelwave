//
//  inkGLU.h
//  ink
//
//  Created by John Lattin on 11/17/11.
//  Copyright (c) 2011 Spiralstorm Games. All rights reserved.
//

#ifndef _INK_GLU_H_
#define _INK_GLU_H_

#ifdef QT_CORE_LIB
#ifdef #ifdef WIN32 || __WIN32 || __WIN32__
#include <OpenGL/glu.h>
#else
#include <GL/glu.h>
#endif
#else
#include "glu.h"
#endif

#endif