/**
 * Whether or not the ocean stays at a fixed position.
 */
private static final boolean FIXED_OCEAN = false;

/**
 * The speed of the waves in the ocean.
 */
private static final float OCEAN_WAVE_SPEED = 0.05f;

/**
 * The amount of waves in total, layered above each other.
 */
private static final int OCEAN_WAVE_COUNT = 5;

/**
 * The total scale of the ocean wave height.
 */
private static final float OCEAN_WAVE_SCALE = 0.2f;

/**
 * The individual amplitudes of the waves.
 */
private static final float[] OCEAN_WAVE_AMPLITUDES = new float[] { 0.1f, 0.05f, 0.05f, 0.025f, 0.01f };

/**
 * The individual wave frequencies of the water.
 */
private static final float[] OCEAN_WAVE_FREQUENCIES = new float[] { 1.0f, 1.0f / 2.0f, 1.0f / 4.0f, 1.0f / 5.0f, 1.0f / 7.0f };

/**
 * The size of the ocean.
 */
private static final float OCEAN_SCALE = 10_000f;

/**
 * The Y offset of the ocean.
 */
private static final float OCEAN_Y_OFFSET = 2_000f;

/**
 * Sampels the ocean's y level at a global X|Z coordinate. Will return a global Y position.
 *
 * @param x The global x coordinate.
 * @param z The global z coordinate.
 * @returns The height of the ocean at (X|Z).
 */
public float sampleOceanY(float x, float z)
{
  float oceanLocalX = x / OCEAN_SCALE;
  float oceanLocalZ = z / OCEAN_SCALE;
  
  float time = FIXED_OCEAN ? 0 : millis() / 1_000f;
  float currentWave = 0;
  for (int i = 0; i < OCEAN_WAVE_COUNT; i++)
  {
    currentWave += OCEAN_WAVE_AMPLITUDES[i]
      * sin((oceanLocalX + time * OCEAN_WAVE_SPEED) * 2f / OCEAN_WAVE_FREQUENCIES[i])
      * cos((oceanLocalZ + time * OCEAN_WAVE_SPEED) * 2.6f / OCEAN_WAVE_FREQUENCIES[i]);
  }
  
  return OCEAN_Y_OFFSET - OCEAN_SCALE * currentWave * OCEAN_WAVE_SCALE;
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
  private static final int OCEAN_FAR_SIZE = 250_000;
  
  /**
   * The size of the skybox that contains clouds.
   */
  private static final int SKYBOX_NEAR_SIZE = 250_000;
  
  /**
   * The height of the skybox that contains clouds.
   */
  private static final int SKYBOX_NEAR_HEIGHT = 100_000;
  
  /**
   * The size of the skybox backdrop.
   */
  private static final int SKYBOX_FAR_SIZE = 500_000;
  
  /**
   * The height of the skybox backdrop.
   */
  private static final int SKYBOX_FAR_HEIGHT = 5_000_000;
  
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
    translate(0, -20_000, 0);
    
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
    shader(oceanFarShader);
    oceanFarShader.set("lighterColor", 105 / 255f, 137 / 255f, 235 / 255f);
    oceanFarShader.set("darkerColor", 37 / 255f, 54 / 255f, 156 / 255f);
    oceanFarShader.set("cameraPosition", camera.getPosition());
    
    pushMatrix();
    
    translate(0, 2500, 0);
    
    beginShape();
    
    // Render the ocean far plane
    vertex(-OCEAN_FAR_SIZE, 0, -OCEAN_FAR_SIZE, 0, 0);
    vertex(-OCEAN_FAR_SIZE, 0, OCEAN_FAR_SIZE, 0, 1);
    vertex(OCEAN_FAR_SIZE, 0, OCEAN_FAR_SIZE, 1, 1);
    vertex(OCEAN_FAR_SIZE, 0, -OCEAN_FAR_SIZE, 1, 0);
    
    endShape();
    popMatrix();
    
    shader(oceanNearShader);
    textureWrap(REPEAT);
    oceanNearShader.set("foamTexture", oceanVoronoi);
    oceanNearShader.set("flowMap", flowMap);
    oceanNearShader.set("time", FIXED_OCEAN ? 0f : millis() / 1_000f);
    
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
    
    translate(-5000, 2100, 0);
    scale(100);
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
