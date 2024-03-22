/**
 * The speed of the waves in the ocean.
 */
private float oceanWaveSpeed = WAVE_SPEED_DEFAULT;

/**
 * The total scale of the ocean wave height.
 */
private float oceanWaveScale = WAVE_SCALE_DEFAULT;

/**
 * The time modifier of the ocean in the X direction.
 */
private float oceanTimeX = 0f;

/**
 * The time modifier of the ocean in the Z direction.
 */
private float oceanTimeZ = 0f;

/**
 * The individual amplitudes of the waves.
 */
private final float[] oceanWaveAmplitudes = WAVE_AMPLITUDES_DEFAULT;

/**
 * The individual wave frequencies of the water.
 */
private final float[] oceanWaveFrequencies = WAVE_FREQUENCIES_DEFAULT;

/**
 * The size of the ocean.
 */
private static final float OCEAN_SCALE = 100f;

/**
 * The Y offset of the ocean.
 */
private static final float OCEAN_Y_OFFSET = 20f;

/**
 * The current velocity of the ocean in the +X direction.
 */
private float oceanSpeedX;

/**
 * The current velocity of the ocean in the +Z direction.
 */
private float oceanSpeedZ;

/**
 * Sampels the ocean's y level at a global X|Z coordinate. Will return a global Y position.
 *
 * @param x The global x coordinate.
 * @param z The global z coordinate.
 * @returns The height of the ocean at (X|Z).
 */
public float sampleOceanY(float x, float z)
{
  // This is a translation of our ocean vertex shader, used for a low amount of points only.
  float oceanLocalX = x / OCEAN_SCALE;
  float oceanLocalZ = z / OCEAN_SCALE;
  
  float currentWave = 0;
  for (int i = 0; i < oceanWaveAmplitudes.length; i++)
  {
    float xComponent = sin((oceanLocalX + oceanTimeX * oceanWaveSpeed) / oceanWaveFrequencies[i]);
    float zComponent = cos((oceanLocalZ + oceanTimeZ * oceanWaveSpeed) / oceanWaveFrequencies[i]);
    
    currentWave += oceanWaveAmplitudes[i] * (xComponent * zComponent);
  }
  
  return OCEAN_Y_OFFSET - OCEAN_SCALE * currentWave * oceanWaveScale;
}

/**
 * Calculates the pressure of a wave in the current flow direction of the ocean at a given point.
 * Note that this is entirely a very crude approximation of how real physics work, since the pressure
 * of a wave is determined by an extremely complex computational model which we simply cannot support.
 *
 * This approximation calculates the derivative of the ocean plane at a given point in the direction
 * of flow of the ocean. Theoretically, the pressure of the wave is highest on the tip of the wave
 * but that one is rough to calculate so we just say the higher the derivative, the higher the pressure.
 *
 * @param x The x position to calculate the pressure around.
 * @param z The z position to calculate the pressure around.
 * @returns A vector representing the force applied to an object in the ocean at that current point.
 */
public PVector calculateOceanFlowPressure(float x, float z)
{
  final float stepSize = 0.1f;
  
  float oceanYBehind = sampleOceanY(x - oceanSpeedX * stepSize, z - oceanSpeedZ * stepSize);
  float oceanYAhead = sampleOceanY(x + oceanSpeedX * stepSize, z + oceanSpeedZ * stepSize);
  
  // This is our approximated slope at that point.
  float derivative = (oceanYAhead - oceanYBehind) / (2f * stepSize);
  
  // Note that angle is in radians
  float angle = abs(atan(derivative));
  
  // Also note that the way we define the wave velocity requires this
  // to be inverted.
  return new PVector(-oceanSpeedX * angle, 0, -oceanSpeedZ * angle);
}

/**
 * The class Environment handles everything regarding the world.
 * This includes the skybox, ocean and island the player is on.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class Environment
{
  /**
   * The size of the ocean's far plane.
   */
  private static final int OCEAN_FAR_SIZE = 2_500;
  
  /**
   * The size of the skybox that contains clouds.
   */
  private static final int SKYBOX_NEAR_SIZE = 2_500;
  
  /**
   * The height of the skybox that contains clouds.
   */
  private static final int SKYBOX_NEAR_HEIGHT = 1_000;
  
  /**
   * The size of the skybox backdrop.
   */
  private static final int SKYBOX_FAR_SIZE = 5_000;
  
  /**
   * The height of the skybox backdrop.
   */
  private static final int SKYBOX_FAR_HEIGHT = 50_000;
  
  /**
   * A constant used in calculating the center point distance of a given hexagon.
   */
  private final float UNIT_HEXAGON_CENTER_DISTANCE = sqrt(3) / 2f;
  
  /**
   * The detailed mesh for the near plane ocean.
   */
  private final PShape oceanMesh;
  
  /**
   * The shader for the near plane ocean.
   */
  private final PShader oceanNearShader;
  
  /**
   * The shader for the far plane ocean.
   */
  private final PShader oceanFarShader;
  
  /**
   * The shader for foliage, discards pixels that contain too high of an alpha.
   * This is far easier than any depth-sorting or other transparency shenanigans.
   */
  private final PShader alphaBlendingShader;
  
  /**
   * The flow map for the ocean near plane. Dictates foam distortion.
   */
  private final PImage flowMap;
  
  /**
   * The voronoi map that gives shape to the ocean's foam.
   */
  private final PImage oceanVoronoi;
  
  /**
   * The clouds for the skybox.
   */
  private final PImage skyboxImage;
  
  /**
   * The island model.
   */
  private final PShape island;
  
  /**
   * The island's foliage.
   */
  private final PShape islandFoliage;
  
  /**
   * Constructs the Environment. Initializes all resources required,
   * mostly textures and some shaders.
   */
  public Environment()
  {
    oceanMesh = loadShape("OceanMesh.obj");
    oceanNearShader = loadShader("OceanNear_Frag.glsl", "OceanNear_Vert.glsl");
    oceanFarShader = loadShader("OceanFar_Frag.glsl", "OceanFar_Vert.glsl");
    alphaBlendingShader = loadShader("AlphaBlending_Frag.glsl", "AlphaBlending_Vert.glsl");
    flowMap = loadImage("FlowMap.png");
    oceanVoronoi = loadImage("Voronoi.png");
    skyboxImage = loadImage("WindWakerBetaSkybox.png");
    
    island = loadShape("SpectacleIsland.obj");
    islandFoliage = loadShape("SpectacleIsland_Transparent.obj");
  }
  
  /**
   * Restores the global lighting configuration.
   */
  public void restoreLights()
  {
    ambientLight(32, 32, 32);
    directionalLight(255, 255, 255, 1, 2, 0);
    lightFalloff(1, 0, 0);
    lightSpecular(0, 0, 0);
  }
  
  /**
   * Note on the name: I personally find "update" more appropriate than draw. I don't quite get why processing only supports
   * a draw function since you have to do everything in there, including a lot of state or physics updating which just feels wrong.
   */
  public void update()
  {
    // We render the skybox before lighting.
    noLights();
    renderSkybox();
    
    restoreLights();
    
    renderOcean();
    renderIsland();
  }
  
  private void renderSkybox()
  {
    pushMatrix();
    
    // Moving everything slightly up makes the clouds start actually in the sky.
    translate(0, -200, 0);
    
    // We rotate it so the seam in the texture can't be seen. It's a beta texture after all
    rotateY(PI);
    
    // The original skybox was a gigantic hexagon far off in the distance. I'm gonna joink that idea because it fits with the texture.
    renderSkyboxHexagon(SKYBOX_NEAR_SIZE, SKYBOX_NEAR_HEIGHT, true);
    
    // Then we render the background color, which is the solid blue above and beyond.
    renderSkyboxHexagon(SKYBOX_FAR_SIZE, SKYBOX_FAR_HEIGHT, false);
    
    popMatrix();
  }
  
  /**
   * Renders the ocean. This is done in two steps, the first being a large, detailless plane with a small fresnel effect
   * to create some minor depth. This plane extends virtually to the skybox (i.e. is very large) and is used to save on
   * resources. This plane also sits lower than our second rendering step's plane: The detailed plane. This one blends
   * seamlessly with our larger plane, but has a lot of subdivisions in order for us to displace the plane in a vertex
   * shader pass for our waves.
   */
  private void renderOcean()
  {
    float currentTime = frameTime / 1_000f;
    
    // The way we tell the ocean in which direction to move is by modifying the "time" in x and z directions
    // differently. For example, moving in X+ and Z- means "forwarding" time in X and "rewinding" time in Z.
    oceanSpeedX = 2 * cos(currentTime / 10f);
    oceanSpeedZ = 2 * sin(currentTime / 10f);
    oceanTimeX += oceanSpeedX * deltaTime;
    oceanTimeZ += oceanSpeedZ * deltaTime;
    
    shader(oceanFarShader);
    oceanFarShader.set("lighterColor", 105 / 255f, 137 / 255f, 235 / 255f);
    oceanFarShader.set("darkerColor", 37 / 255f, 54 / 255f, 156 / 255f);
    oceanFarShader.set("cameraPosition", camera.getPosition());
    
    pushMatrix();
    
    translate(0, 25, 0);
    
    beginShape();
    
    // Render the ocean far plane
    vertex(-OCEAN_FAR_SIZE, 0, -OCEAN_FAR_SIZE, 0, 0);
    vertex(-OCEAN_FAR_SIZE, 0, OCEAN_FAR_SIZE, 0, 1);
    vertex(OCEAN_FAR_SIZE, 0, OCEAN_FAR_SIZE, 1, 1);
    vertex(OCEAN_FAR_SIZE, 0, -OCEAN_FAR_SIZE, 1, 0);
    
    endShape();
    popMatrix();
    
    // Render the ocean near plane. Updates all variables to our provided values and then draws the ocean mesh
    // accordingly to our shader settings.
    shader(oceanNearShader);
    textureWrap(REPEAT);
    oceanNearShader.set("foamTexture", oceanVoronoi);
    oceanNearShader.set("flowMap", flowMap);
    oceanNearShader.set("time", currentTime);
    
    oceanNearShader.set("waveSpeed", oceanWaveSpeed);
    oceanNearShader.set("waveScale", oceanWaveScale);
    oceanNearShader.set("directedTime", oceanTimeX, oceanTimeZ);
    
    oceanNearShader.set("amplitudes", oceanWaveAmplitudes[0], oceanWaveAmplitudes[1], oceanWaveAmplitudes[2], oceanWaveAmplitudes[3]);
    oceanNearShader.set("frequencies", oceanWaveFrequencies[0], oceanWaveFrequencies[1], oceanWaveFrequencies[2], oceanWaveFrequencies[3]);
    
    pushMatrix();
    
    translate(0, OCEAN_Y_OFFSET, 0);
    scale(OCEAN_SCALE);
    
    // Render the ocean near plane
    shape(oceanMesh);
    
    popMatrix();
    resetShader();
  }
  
  PShape measuringStick;
  
  /**
   * Renders the model of the island. Foliage and island itself are separated
   * due to transparency requiring a different shader.
   */
  private void renderIsland()
  {
    pushMatrix();
    
    translate(-50, 21, 0);
    rotateX(PI);
    
    shape(island);
    
    shader(alphaBlendingShader);
    shape(islandFoliage);
    resetShader();
    
    popMatrix();
  }
  
  /**
   * Renders a hexagon. The textured/colored parts are specific for the skybox, otherwise this render code would be portable.
   * And yes, this method calls a box a hexagon and I like it for that.
   *
   * @param size The size, or rather radius of the hexagon.
   * @param height The height of the hexagon.
   * @param textured Whether or not to use the skybox texture or solid color.
   */
  private void renderSkyboxHexagon(float size, float height, boolean textured)
  {
    noStroke();
    textureMode(NORMAL);
    if (!textured)
    {
      // If we don't use a texture, we use the solid sky color.
      fill(82, 153, 217);
    }
    
    // We do this for each side of the hexagon.
    for (int i = 0; i < 6; i++)
    {
      pushMatrix();
      
      // We translate in the direction of the face we want to paint. This happens in steps of 60° on the unit circle.
      translate(
        cos(2 * PI * i / 6f) * size * UNIT_HEXAGON_CENTER_DISTANCE,
        0,
        sin(2 * PI * i / 6f) * size * UNIT_HEXAGON_CENTER_DISTANCE);
        
      // We turn the faces in steps of 60°, starting at 270 so that everything aligns. This includes
      // the UV coordinates of the texture.
      rotateY((270 - 60 * i) * PI / 180f);
      
      // And start drawing.
      beginShape();
      if (textured)
      {
        // We require our texture here.
        texture(skyboxImage);
      }
      
      // We draw a quad here with the given size and height, centered around the origin of our transformation.
      // We give this quad UV coordinates that increase in steps of 1/6 to go through our texture horizontally.
      // This will wrap around once.
      vertex(-size / 2, -height / 2, 0, i / 6f, 0);
      vertex(-size / 2, height / 2, 0, i / 6f, 1);
      vertex(size / 2, height / 2, 0, (i + 1) / 6f, 1);
      vertex(size / 2, -height / 2, 0, (i + 1) / 6f, 0);
      
      // Then we finalize the shape and restore the position.
      endShape();
      popMatrix();
    }
  }
}
