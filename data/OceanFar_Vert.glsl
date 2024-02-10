uniform mat4 transformMatrix;

attribute vec3 position;
attribute vec3 normal;

varying vec3 worldPosition;
varying vec3 normalVector;

void main() {
  worldPosition = position;
  normalVector = normal;
  gl_Position = transformMatrix * vec4(position.xyz, 1.0);
}
