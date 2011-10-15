/*
    max.jit.gl.syphonclient.m
    jit.gl.syphonclient
	
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
#include "ext_obex.h"

#import <Syphon/Syphon.h>

typedef struct _max_jit_gl_syphon_client 
{
	t_object		ob;
	void			*obex;
	
	// output texture outlet
	void			*texout;
    void            *dumpout;
    
} t_max_jit_gl_syphon_client;

t_jit_err jit_gl_syphon_client_init(void); 

void *max_jit_gl_syphon_client_new(t_symbol *s, long argc, t_atom *argv);
void max_jit_gl_syphon_client_free(t_max_jit_gl_syphon_client *x);

// custom draw
void max_jit_gl_syphon_client_bang(t_max_jit_gl_syphon_client *x);
void max_jit_gl_syphon_client_draw(t_max_jit_gl_syphon_client *x, t_symbol *s, long argc, t_atom *argv);

//custom list outof available servers via the dumpout outlet.
void max_jit_gl_syphon_client_getavailableservers(t_max_jit_gl_syphon_client *x);

t_class *max_jit_gl_syphon_client_class;

t_symbol *ps_jit_gl_texture,*ps_draw,*ps_out_name, *ps_appname, *ps_servername, *ps_clear;

void main(void)
{	
	void *classex, *jitclass;
	
	// initialize our Jitter class
	jit_gl_syphon_client_init();	
	
	// create our Max class
	setup((t_messlist **)&max_jit_gl_syphon_client_class, 
		  (method)max_jit_gl_syphon_client_new, (method)max_jit_gl_syphon_client_free, 
		  (short)sizeof(t_max_jit_gl_syphon_client), 0L, A_GIMME, 0);
	
	// specify a byte offset to keep additional information about our object
	classex = max_jit_classex_setup(calcoffset(t_max_jit_gl_syphon_client, obex));
	
	// look up our Jitter class in the class registry
	jitclass = jit_class_findbyname(gensym("jit_gl_syphon_client"));	
		
	// wrap our Jitter class with the standard methods for Jitter objects
    max_jit_classex_standard_wrap(classex, jitclass, 0); 	
	
	// custom draw handler so we can output our texture.
	// override default ob3d bang/draw methods
	addbang((method)max_jit_gl_syphon_client_bang);
	max_addmethod_defer_low((method)max_jit_gl_syphon_client_draw, "draw");  
	
    max_addmethod_defer_low((method)max_jit_gl_syphon_client_getavailableservers, "getavailableservers");
    
   	// use standard ob3d assist method
    addmess((method)max_jit_ob3d_assist, "assist", A_CANT,0);  
	
	// add methods for 3d drawing
    max_ob3d_setup();
	ps_jit_gl_texture = gensym("jit_gl_texture");
	ps_draw = gensym("draw");
	ps_out_name = gensym("out_name");
    ps_servername = gensym("servername");
    ps_appname = gensym("appname");
    ps_clear = gensym("clear");
}

void max_jit_gl_syphon_client_free(t_max_jit_gl_syphon_client *x)
{
	max_jit_ob3d_detach(x);

	// lookup our internal Jitter object instance and free
	if(max_jit_obex_jitob_get(x))
		jit_object_free(max_jit_obex_jitob_get(x));
	
	// free resources associated with our obex entry
	max_jit_obex_free(x);
}

void max_jit_gl_syphon_client_bang(t_max_jit_gl_syphon_client *x)
{
//	typedmess((t_object *)x,ps_draw,0,NULL);
	max_jit_gl_syphon_client_draw(x,ps_draw,0,NULL);

}

void max_jit_gl_syphon_client_draw(t_max_jit_gl_syphon_client *x, t_symbol *s, long argc, t_atom *argv)
{
	t_atom a;
	// get the jitter object
	t_jit_object *jitob = (t_jit_object*)max_jit_obex_jitob_get(x);
	
	// call the jitter object's draw method
	jit_object_method(jitob,s,s,argc,argv);
	
	// query the texture name and send out the texture output 
	jit_atom_setsym(&a,jit_attr_getsym(jitob,ps_out_name));
	outlet_anything(x->texout,ps_jit_gl_texture,1,&a);
}

void max_jit_gl_syphon_client_getavailableservers(t_max_jit_gl_syphon_client *x)
{    
    t_atom atomName;
    t_atom atomHostName;
    
    // send a clear first.
    outlet_anything(max_jit_obex_dumpout_get(x), ps_clear, 0, 0); 

    for(NSDictionary* serverDict in [[SyphonServerDirectory sharedDirectory] servers])
    {
        NSString* serverName = [serverDict valueForKey:SyphonServerDescriptionNameKey];
        NSString* serverAppName = [serverDict valueForKey:SyphonServerDescriptionAppNameKey];
        
        const char* name = [serverName cStringUsingEncoding:NSUTF8StringEncoding];
        const char* hostName = [serverAppName cStringUsingEncoding:NSUTF8StringEncoding];
                
        atom_setsym(&atomName, gensym((char*)name));
        atom_setsym(&atomHostName, gensym((char*)hostName));

        outlet_anything(x->dumpout, ps_servername, 1, &atomName); 
        outlet_anything(x->dumpout, ps_appname, 1, &atomHostName); 
    }   
}

void *max_jit_gl_syphon_client_new(t_symbol *s, long argc, t_atom *argv)
{
	t_max_jit_gl_syphon_client *x;
	void *jit_ob;
	long attrstart;
	t_symbol *dest_name_sym = _jit_sym_nothing;
	
	if (x = (t_max_jit_gl_syphon_client *) max_jit_obex_new(max_jit_gl_syphon_client_class, gensym("jit_gl_syphon_client"))) 
	{
		// get first normal arg, the destination name
		attrstart = max_jit_attr_args_offset(argc,argv);
		if (attrstart&&argv) 
		{
			jit_atom_arg_getsym(&dest_name_sym, 0, attrstart, argv);
		}
		
		// instantiate Jitter object with dest_name arg
		if (jit_ob = jit_object_new(gensym("jit_gl_syphon_client"), dest_name_sym)) 
		{
			// set internal jitter object instance
			max_jit_obex_jitob_set(x, jit_ob);
			
			// process attribute arguments 
			max_jit_attr_args(x, argc, argv);		
			

            // add a general purpose outlet (rightmost)
            x->dumpout = outlet_new(x,NULL);
			max_jit_obex_dumpout_set(x, x->dumpout);

			// this outlet is used to shit out textures! yay!
			x->texout = outlet_new(x, "jit_gl_texture");
        } 
		else 
		{
			error("jit.gl.syphon_server: could not allocate object");
			freeobject((t_object *)x);
			x = NULL;
		}
	}
	return (x);
}



