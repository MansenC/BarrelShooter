uniform sampler2D texture;

uniform vec2 texOffset;

varying vec4 vertColor;
varying vec4 backVertColor;
varying vec4 vertTexCoord;

void main() {
  vec4 color = texture2D(texture, vertTexCoord.st) * (gl_FrontFacing ? vertColor : backVertColor);
  if (color.a < 0.5) {
    // This is essentially poor man's alpha blending. If we have transparency in our foliage then we discard
    // this pixel so that it doesn't write to the depth buffer and we can render what's behind it.
    // This is _costly_ though since discard for one should be avoided due to pixel data dependency and what not
    // and furthermore this is a branching operation. But it works.
    discard;
  }
  
  gl_FragColor = color;
}
