//
//  inkTessellator.h
//  ink
//
//  Created by John Lattin on 11/9/11.
//  Copyright (c) 2011 Spiralstorm Games. All rights reserved.
//

#ifndef _INK_TESSELLATOR_H_
#define _INK_TESSELLATOR_H_

#include "inkHeader.h"

#include "inkArray.h"
#include "inkRenderGroup.h"

#include "inkTypes.h"
// TODO: Remove
#include "PXGLUtils.h"

typedef struct
{
	void *gluTessellator;

	inkArray *renderGroups; // Weak
	inkRenderGroup *currentRenderGroup;
	inkArray *combineVertices;

	bool contourBegan;
	bool polygonBegan;
} inkTessellator;

inkExtern inkTessellator *inkTessellatorCreate();
inkExtern void inkTessellatorDestroy(inkTessellator* tessellator);

inkExtern void inkTessellatorBeginPolygon(inkTessellator* tessellator, inkArray *renderGroups);
inkExtern void inkTessellatorEndPolygon(inkTessellator* tessellator);
inkExtern void inkTessellatorBeginContour(inkTessellator* tessellator);
inkExtern void inkTessellatorEndContour(inkTessellator* tessellator);

inkExtern void inkTessellatorAddPoint(inkTessellator* tessellator, INKvertex* vertex);
//inkExtern void inkTessellatorExpandRenderGroup(inkTessellator* tessellator, inkRenderGroup* renderGroup);

#endif