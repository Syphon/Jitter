/*
    jit.gl.syphonserver.m
    jit.gl.syphonserver
	
    Copyright 2010 bangnoise (Tom Butterworth) & vade (Anton Marini).
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
    DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "jit.common.h"
#include "jit.gl.h"
#include "jit.gl.ob3d.h"
#include "ext_obex.h"

#import <Cocoa/Cocoa.h>
#import <Syphon/Syphon.h>

t_jit_err jit_ob3d_dest_name_set(t_jit_object *x, void *attr, long argc, t_atom *argv);

typedef struct _jit_gl_syphon_server 
{
	// Max object
	t_object			ob;			
	// 3d object extension.  This is what all objects in the GL group have in common.
	void				*ob3d;
		
	// internal jit.gl.texture object, which we use to handle matrix input.
	t_symbol *texture;
	
	// the name of the texture we should draw from - our internal one (for matrix input) or an external one
	t_symbol *textureSource;
	
	// attributes
	t_symbol			*servername;
	
	// Need our syphon instance here.
	SyphonServer* syServer;
	
} t_jit_gl_syphon_server;

void *_jit_gl_syphon_server_class;

#pragma mark -
#pragma mark Function Declarations

// init/constructor/free
t_jit_err jit_gl_syphon_server_init(void);
t_jit_gl_syphon_server *jit_gl_syphon_server_new(t_symbol * dest_name);
void jit_gl_syphon_server_free(t_jit_gl_syphon_server *jit_gl_syphon_server_instance);

// handle context changes - need to rebuild SyphonServer & textures here.
t_jit_err jit_gl_syphon_server_dest_closing(t_jit_gl_syphon_server *jit_gl_syphon_server_instance);
t_jit_err jit_gl_syphon_server_dest_changed(t_jit_gl_syphon_server *jit_gl_syphon_server_instance);

// draw
t_jit_err jit_gl_syphon_server_draw(t_jit_gl_syphon_server *jit_gl_syphon_server_instance);

// handle input texture
t_jit_err jit_gl_syphon_server_jit_gl_texture(t_jit_gl_syphon_server *jit_gl_syphon_server_instance, t_symbol *s, int argc, t_atom *argv);

// handle input matrix
t_jit_err jit_gl_syphon_server_jit_matrix(t_jit_gl_syphon_server *jit_gl_syphon_server_instance, t_symbol *s, int argc, t_atom *argv);

//attributes
// @servername, for server human readable name
t_jit_err jit_gl_syphon_server_servername(t_jit_gl_syphon_server *jit_gl_syphon_server_instance, void *attr, long argc, t_atom *argv);

// symbols
t_symbol *ps_servername;
t_symbol *ps_texture;
t_symbol *ps_width;
t_symbol *ps_height;
t_symbol *ps_glid;
t_symbol *ps_gltarget;
t_symbol *ps_flip;
t_symbol *ps_automatic;
t_symbol *ps_drawto;
t_symbol *ps_draw;

// for our internal texture
t_symbol *ps_jit_gl_texture;

//
// Function implementations
//

#pragma mark -
#pragma mark Init, New, Cleanup, Context changes

t_jit_err jit_gl_syphon_server_init(void) 
{
	// create our class
	_jit_gl_syphon_server_class = jit_class_new("jit_gl_syphon_server", 
												(method)jit_gl_syphon_server_new, (method)jit_gl_syphon_server_free,
												sizeof(t_jit_gl_syphon_server),A_DEFSYM,0L);
	
	// setup our OB3D flags to indicate our capabilities.
	long ob3d_flags = JIT_OB3D_NO_MATRIXOUTPUT; // no matrix output
	ob3d_flags |= JIT_OB3D_NO_ROTATION_SCALE;
	ob3d_flags |= JIT_OB3D_NO_POLY_VARS;
	ob3d_flags |= JIT_OB3D_NO_FOG;
	ob3d_flags |= JIT_OB3D_NO_LIGHTING_MATERIAL;
	ob3d_flags |= JIT_OB3D_NO_DEPTH;
	ob3d_flags |= JIT_OB3D_NO_COLOR;
	
	// set up object extension for 3d object, customized with flags
	void *ob3d;
	ob3d = jit_ob3d_setup(_jit_gl_syphon_server_class, calcoffset(t_jit_gl_syphon_server, ob3d), ob3d_flags);
		
	// add attributes
	long attrflags = JIT_ATTR_GET_DEFER_LOW | JIT_ATTR_SET_USURP_LOW;
	t_jit_object *attr;
	
	attr = jit_object_new(_jit_sym_jit_attr_offset,"servername",_jit_sym_symbol,attrflags,
						  (method)0L, jit_gl_syphon_server_servername, calcoffset(t_jit_gl_syphon_server, servername));	
	jit_class_addattr(_jit_gl_syphon_server_class,attr);	
	
	// define our dest_closing and dest_changed methods. 
	// these methods are called by jit.gl.render when the 
	// destination context closes or changes: for example, when 
	// the user moves the window from one monitor to another. Any 
	// resources your object keeps in the OpenGL machine 
	// (e.g. textures, display lists, vertex shaders, etc.) 
	// will need to be freed when closing, and rebuilt when it has 
	// changed. In this object, these functions do nothing, and 
	// could be omitted.
	
	// OB3D methods
	// must register for ob3d use
	jit_class_addmethod(_jit_gl_syphon_server_class, (method)jit_object_register, "register", A_CANT, 0L);
	jit_class_addmethod(_jit_gl_syphon_server_class, (method)jit_gl_syphon_server_dest_closing, "dest_closing", A_CANT, 0L);
	jit_class_addmethod(_jit_gl_syphon_server_class, (method)jit_gl_syphon_server_dest_changed, "dest_changed", A_CANT, 0L);
	jit_class_addmethod(_jit_gl_syphon_server_class, (method)jit_gl_syphon_server_draw, "ob3d_draw", A_CANT, 0L);
	
	// handle texture input - we need to explictly handle jit_gl_texture messages so we can set our internal texture reference
	jit_class_addmethod(_jit_gl_syphon_server_class, (method)jit_gl_syphon_server_jit_gl_texture, "jit_gl_texture", A_GIMME, 0L);

	// handle matrix inputs
	jit_class_addmethod(_jit_gl_syphon_server_class, (method)jit_gl_syphon_server_jit_matrix, "jit_matrix", A_USURP_LOW, 0);	
	
	//symbols
	ps_servername = gensym("servername");
	ps_texture = gensym("texture");
	ps_width = gensym("width");
	ps_height = gensym("height");
	ps_glid = gensym("glid");
	ps_gltarget = gensym("gltarget");
	ps_flip = gensym("flip");
	ps_automatic = gensym("automatic");
	ps_jit_gl_texture = gensym("jit_gl_texture");
	ps_drawto = gensym("drawto");
	ps_draw = gensym("draw");
	
	jit_class_register(_jit_gl_syphon_server_class);

	return JIT_ERR_NONE;
}

t_jit_gl_syphon_server *jit_gl_syphon_server_new(t_symbol * dest_name)
{
	post("New Server");
	
	t_jit_gl_syphon_server *jit_gl_syphon_server_instance = NULL;
	
	// make jit object
	if (jit_gl_syphon_server_instance = (t_jit_gl_syphon_server *)jit_object_alloc(_jit_gl_syphon_server_class)) 
	{
		post("Attach OB3D");

		// create and attach ob3d
		jit_ob3d_new(jit_gl_syphon_server_instance, dest_name);

		// TODO : is this right ? 
		// set up attributes
		jit_attr_setsym(jit_gl_syphon_server_instance->servername, _jit_sym_name, gensym("servername"));

		post("Create Texture");

		// instantiate a single internal jit.gl.texture should we need it.
		jit_gl_syphon_server_instance->texture = jit_object_new(ps_jit_gl_texture,jit_attr_getsym(jit_gl_syphon_server_instance,ps_drawto));
		
		if (jit_gl_syphon_server_instance->texture)
		{
			post("Setup Texture");

			// set texture attributes.
			t_symbol *name =  jit_symbol_unique();
			jit_attr_setsym(jit_gl_syphon_server_instance->texture,_jit_sym_name,name);
			jit_attr_setsym(jit_gl_syphon_server_instance->texture,gensym("defaultimage"),gensym("white"));
			jit_attr_setlong(jit_gl_syphon_server_instance->texture,gensym("rectangle"), 1);
			jit_attr_setsym(jit_gl_syphon_server_instance->texture, gensym("mode"),gensym("dynamic"));	
			
			jit_attr_setsym(jit_gl_syphon_server_instance, ps_texture, name);
			
			jit_gl_syphon_server_instance->textureSource = name;
		} 
		else
		{
			post("error creating internal texture object");
			jit_object_error((t_object *)jit_gl_syphon_server_instance,"jit.gl.syphonserver: could not create texture");
			jit_gl_syphon_server_instance->textureSource = _jit_sym_nothing;		
		}
	} 
	else 
	{
		jit_gl_syphon_server_instance = NULL;
	}

	return jit_gl_syphon_server_instance;
}

void jit_gl_syphon_server_free(t_jit_gl_syphon_server *jit_gl_syphon_server_instance)
{
	// free our ob3d data
	if(jit_gl_syphon_server_instance)
		jit_ob3d_free(jit_gl_syphon_server_instance);
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	// if we have an existing Syphon Server we need to destroy it, and make a new one, since the context has changed underneath us.
	if(jit_gl_syphon_server_instance->syServer)
	{
		[jit_gl_syphon_server_instance->syServer release];
		jit_gl_syphon_server_instance->syServer = nil;
	}
	
	[pool drain];
	
	// free our internal texture
	if(jit_gl_syphon_server_instance->texture)
		jit_object_free(jit_gl_syphon_server_instance->texture);
}

t_jit_err jit_gl_syphon_server_dest_closing(t_jit_gl_syphon_server *jit_gl_syphon_server_instance)
{
	return JIT_ERR_NONE;
}

t_jit_err jit_gl_syphon_server_dest_changed(t_jit_gl_syphon_server *jit_gl_syphon_server_instance)
{	
	//post("Destination Changed");
	
	// try and find a context.
	t_jit_gl_context jit_ctx = 0;

	//post("Getting Context");

	// jitter context
	jit_ctx = jit_gl_get_context();

	//post("Got Context");

	if(jit_ctx)
	{
		//post("Have Context");
		
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

		if(jit_gl_syphon_server_instance->syServer)
        {
			//post("Removing Server");
			
            [jit_gl_syphon_server_instance->syServer release];
            jit_gl_syphon_server_instance->syServer = nil;
		}
        
		//post("Creating Server");
		
		jit_gl_syphon_server_instance->syServer = [[SyphonServer alloc] initWithName:[NSString stringWithCString:jit_gl_syphon_server_instance->servername->s_name encoding:NSASCIIStringEncoding]
                                                                             context:CGLGetCurrentContext()
                                                                             options:nil];
        
		[pool drain];
		
		if (jit_gl_syphon_server_instance->texture)
			jit_attr_setsym(jit_gl_syphon_server_instance->texture,ps_drawto,jit_attr_getsym(jit_gl_syphon_server_instance,ps_drawto));	
	}
	else {
		post("No OpenGL context detected");
	}
	
	if(jit_gl_syphon_server_instance->syServer == nil)
	{
		post("jit.gl.syphonserver: Could not create Syphon Server.. bailing");
		return JIT_ERR_GENERIC;
	}
	return JIT_ERR_NONE;
}

#pragma mark -
#pragma mark Input Imagery, Texture/ Matrix

// handle matrix input
t_jit_err jit_gl_syphon_server_jit_matrix(t_jit_gl_syphon_server *jit_gl_syphon_server_instance, t_symbol *s, int argc, t_atom *argv)
{
//	post("matrix input");
	
	t_symbol *name;
	void *m;
	
	if ((name=jit_atom_getsym(argv)) != _jit_sym_nothing)
	{
		m = jit_object_findregistered(name);
		if (!m)
		{
			jit_object_error((t_object *)jit_gl_syphon_server_instance,"jit.gl.syphonserver: couldn't get matrix object!");
			return JIT_ERR_GENERIC;
		}
	}
	
	if (jit_gl_syphon_server_instance->texture)
	{				
		jit_object_method(jit_gl_syphon_server_instance->texture,s,s,argc,argv);
		
		// add texture to ob3d texture list
		t_symbol *texName = jit_attr_getsym(jit_gl_syphon_server_instance->texture, _jit_sym_name);
		jit_attr_setsym(jit_gl_syphon_server_instance,ps_texture,texName);
		jit_gl_syphon_server_instance->textureSource = texName;
	}
	return JIT_ERR_NONE;
}

// handle texture input 
t_jit_err jit_gl_syphon_server_jit_gl_texture(t_jit_gl_syphon_server *jit_gl_syphon_server_instance, t_symbol *s, int argc, t_atom *argv)
{
//	post("texture input");
	
    t_symbol *name = jit_atom_getsym(argv);
	
    if (name)
    {
		// add texture to ob3d texture list
		jit_attr_setsym(jit_gl_syphon_server_instance,ps_texture,name);
		jit_gl_syphon_server_instance->textureSource = name;
	}
	return JIT_ERR_NONE;
}

#pragma mark -
#pragma mark Draw

t_jit_err jit_gl_syphon_server_draw(t_jit_gl_syphon_server *jit_gl_syphon_server_instance)
{
	if (!jit_gl_syphon_server_instance)
		return JIT_ERR_INVALID_PTR;

	if(jit_gl_syphon_server_instance->textureSource)
	{
		// cache/restore context in case in capture mode
		
		// TODO: necessary ? JKC says no unless context changed above? should be set during draw for you. 		
		t_jit_gl_context ctx = jit_gl_get_context();
		jit_ob3d_set_context(jit_gl_syphon_server_instance);
		
		// get our latest texture info.
		t_jit_object *texture = (t_jit_object*)jit_object_findregistered(jit_gl_syphon_server_instance->textureSource);
					
		GLuint texName = jit_attr_getlong(texture,ps_glid);
		GLuint width = jit_attr_getlong(texture,ps_width);
		GLuint height = jit_attr_getlong(texture,ps_height);
		GLuint texTarget = jit_attr_getlong(texture, ps_gltarget);

		BOOL flip = ((BOOL)  jit_attr_getlong(texture,ps_flip));

		// all of these must be > 0
		if(texName && width && height)
		{
			// For debugging..
			//post ("jit.gl.syphonserver: recieved texture object: %i %i %i %i", texName, width, height, (texTarget == GL_TEXTURE_RECTANGLE_EXT) ? 1	: 0);
					
			if(jit_gl_syphon_server_instance->syServer)
			{	
				// This is a temporary fix until we resolve the issue in a new Syphon Framework (Public Beta 3 or what not)
				// Jitter uses multuple texture coordinate arrays on different units, and we (Syphon) erronously do not re-set  
				// our internal Client Active Texture in the framework to GL_TEXTURE0, thus our texture coord array is not set.
				glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
				glClientActiveTexture(GL_TEXTURE0);

				NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
				
				// output our frame
				[jit_gl_syphon_server_instance->syServer publishFrameTexture:texName
															   textureTarget:texTarget
																 imageRegion:NSMakeRect(0.0, 0.0, width, height)
														   textureDimensions:NSMakeSize(width, height)
																	 flipped:flip];
				[pool drain];
				
				glPopClientAttrib();
			}
		}
		
		jit_gl_set_context(ctx);
	}
	else
	{
		post("No texture!?");
	}

	return JIT_ERR_NONE;
}
		
#pragma mark -
#pragma mark Attributes

// attributes
// @servername
t_jit_err jit_gl_syphon_server_servername(t_jit_gl_syphon_server *jit_gl_syphon_server_instance, void *attr, long argc, t_atom *argv)
{
	t_symbol *srvname;

	if(jit_gl_syphon_server_instance)
	{	
		//post("have server");

		if (argc && argv)
		{
			srvname = jit_atom_getsym(argv);

			jit_gl_syphon_server_instance->servername = srvname;
		} 
		else
		{
			// no args, set to zero
			jit_gl_syphon_server_instance->servername = gensym("jig.gl.syphonserver");
		}
		
		// set the servers name to 
		// get our name and set it 
		[jit_gl_syphon_server_instance->syServer setName:[NSString stringWithCString:jit_gl_syphon_server_instance->servername->s_name
																			encoding:NSASCIIStringEncoding]];
		
	}
	return JIT_ERR_NONE;
}
