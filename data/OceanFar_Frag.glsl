precision highp float;

uniform vec3 cameraPosition;
uniform vec3 lighterColor;
uniform vec3 darkerColor;

varying vec3 worldPosition;
varying vec3 normalVector;

float fresnel(vec3 direction, vec3 normal) {
  vec3 normalDirection = normalize(direction);
  vec3 halfDirection = normalize(normalize(normal) + normalDirection);
  
  return pow(max(dot(halfDirection, normalDirection), 0.0), 5.0);
}

void main() {
  float fresnelFactor = min(10 * pow(fresnel(worldPosition - cameraPosition, normalVector), 2), 1);
  vec3 color = mix(lighterColor, darkerColor, fresnelFactor);
  gl_FragColor = vec4(color.rgb, 1.0);
}
