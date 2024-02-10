uniform mat4 transformMatrix;

attribute vec3 position;
attribute vec3 normal;
attribute vec2 texCoord;

uniform float time;

varying vec3 localPosition;
varying vec2 uvCoordinates;

void main() {
  const float waveSpeed = .05;
  
  const int waveCount = 5;
  const float amplitudes[waveCount] = float[](0.1, 0.05, 0.05, 0.025, 0.01);
  const float frequencies[waveCount] = float[](1.0, 1.0 / 2.0, 1.0 / 4.0, 1.0 / 5.0, 1.0 / 7.0);

  localPosition = position;
  uvCoordinates = texCoord;
  
  float currentWave = 0;
  for (int i = 0; i < waveCount; i++) {
    currentWave += amplitudes[i] * sin((position.x + time * waveSpeed) * 2 / frequencies[i]) * cos((position.z + time * waveSpeed) * 2.6 / frequencies[i]);
  }
  
  vec3 newPosition = vec3(position.x, position.y - currentWave * 0.2, position.z);
  
  gl_Position = transformMatrix * vec4(newPosition.xyz, 1.0);
}
