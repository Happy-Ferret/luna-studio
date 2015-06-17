#ifdef GL_ES		
precision highp float;
#endif	

attribute vec2 pos;
varying vec2 coords;

uniform float camFactor;
uniform vec2 camPan;
uniform vec2 screenSize;

void main()
{
	gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
	coords = (pos - camPan)*camFactor + screenSize/2.0;
}