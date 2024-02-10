precision highp float;

uniform sampler2D foamTexture;
uniform sampler2D flowMap;
uniform float time;

varying vec3 localPosition;
varying vec2 uvCoordinates;

vec3 normalFromTexture(sampler2D texture, vec2 uv, float offset, float strength) {
  offset = pow(offset, 3) * 0.1;
  
  vec2 offsetU = vec2(uv.x + offset, uv.y);
  vec2 offsetV = vec2(uv.x, uv.y + offset);
  
  float normalSample = texture2D(texture, uv).x;
  float uSample = texture2D(texture, offsetU).x;
  float vSample = texture2D(texture, offsetV).x;
  
  vec3 va = vec3(1, 0, (uSample - normalSample) * strength);
  vec3 vb = vec3(0, 1, (vSample - normalSample) * strength);
  return normalize(cross(va, vb));
}

void main() {
  const vec4 waterColor = vec4(53.0 / 255.0, 164.0 / 255.0, 255.0 / 255.0, 1);
  const vec4 lightFoamColor = vec4(1, 1, 1, 1);
  const vec4 darkFoamColor = vec4(42.0 / 255.0, 153.0 / 255.0, 245.0 / 255.0, 1);
  
  const float foamDistance = 1;
  const float flowSpeed = 0.01;
  const float flowStrength = 0.0075;
  const float size = 30;
  
  // Distort UVs
  vec2 uvOffset = uvCoordinates + (time * flowSpeed / size).xx;
  vec3 flowNormals = normalFromTexture(flowMap, uvOffset, 0.5, 8) * flowStrength.xxx;
  
  // Sample the form voronoi image
  vec2 uvNormals = (uvCoordinates + flowNormals.xy) * size.xx;
  vec2 offsetUVNormals = uvNormals + vec2(0.15, 0.15);
  vec4 offsetVoronoi = texture2D(foamTexture, offsetUVNormals);
  vec4 offsetVoronoiColor = mix(waterColor, darkFoamColor, offsetVoronoi);
  
  // Now the full color based on the base uv normals
  vec4 mainVoronoi = texture2D(foamTexture, uvNormals);
  vec4 mainVoronoiColor = mix(offsetVoronoiColor, lightFoamColor, mainVoronoi);

  vec3 albedo = mainVoronoiColor.xyz;
  float alpha = 1 - min(1, 2 * max(length(localPosition) - 0.5, 0));
  gl_FragColor = vec4(albedo.xyz, alpha);
}
