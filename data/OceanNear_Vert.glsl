uniform mat4 transformMatrix;

attribute vec3 position;
attribute vec3 normal;
attribute vec2 texCoord;

uniform float waveSpeed;
uniform float waveScale;
uniform vec2 directedTime;

uniform vec4 amplitudes;
uniform vec4 frequencies;

varying vec3 localPosition;
varying vec2 uvCoordinates;

void main() {
  localPosition = position;
  uvCoordinates = texCoord;
  
  float currentWave = 0;
  for (int i = 0; i < 4; i++) {
    float xComponent = sin((position.x + directedTime.x * waveSpeed) / frequencies[i]);
    float zComponent = cos((position.z + directedTime.y * waveSpeed) / frequencies[i]);
  
    currentWave += amplitudes[i] * (xComponent * zComponent);
  }
  
  vec3 newPosition = vec3(position.x, position.y - currentWave * waveScale, position.z);
  
  gl_Position = transformMatrix * vec4(newPosition.xyz, 1.0);
}
