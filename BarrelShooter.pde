// We keep our global variables here. These are kept to a minimum since I personally detest the usage of those.
// Every global variable represents a class instance that handles a certain part of the rendering or processing pipeline.
Camera camera;
Environment environment;

/**
 * Initial setup of basically everything. Loads into the title screen after setting up everything for the
 * rendering context.
 */
void setup()
{
  // This game runs full-screen.
  fullScreen(P3D);
  
  // Anti-aliasing 4x
  smooth(4);
  
  // We initialize everything.
  camera = new Camera(new PVector(-4175, 905, 333));
  environment = new Environment();
  
  camera.setCursorLocked(true);
}

/**
 * The core loop for this program. Handles rendering and everything else.
 */
void draw()
{
  background(0);
  
  // We first update our camera, process the input and update the position.
  camera.update();
  
  // Then we handle the environment. This includes lighting.
  environment.update();
}
