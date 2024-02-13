// We keep our global variables here. These are kept to a minimum since I personally detest the usage of those.
// Every global variable represents a class instance that handles a certain part of the rendering or processing pipeline.
Camera camera;
Environment environment;
Cannon cannon;

int lastFrameMillis;
float deltaTime;

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
  
  // Start our physics manager
  PhysicsManager.start();
  
  // We initialize everything.
  camera = new Camera(new PVector(-4175, 905, 333));
  environment = new Environment();
  cannon = new Cannon(new PVector(-3000, 1040, 333));
  
  camera.setCursorLocked(true);
  
  // Load external global variables :)
  cannonballShape = loadShape("Cannonball.obj");
}

/**
 * The core loop for this program. Handles rendering and everything else.
 */
void draw()
{
  background(0);
  
  // We calculate the delta time in seconds.
  int now = millis();
  deltaTime = (now - lastFrameMillis) / 1000f;
  lastFrameMillis = now;
  
  // First we handle the environment. This includes lighting.
  environment.update();
  
  // After that we update everything else related to our game and simulation
  cannon.update();
  
  // Lastly we update our camera, process the input and update the position.
  camera.update();
  
  // Finally we clean up our key and mouse data for this frame.
  framePressedKeys.clear();
  framePressedMouseButtons.clear();
}

/**
 * This overrides {@link PApplet#exit} in order to listen for a scheduled exit.
 * With this we can safely stop our {@link PhysicsManager} so that the thread doesn't
 * continue executing in the background. Technically, the program gets terminated after
 * here but it feels cleaner to actually shutdown a thread.
 */
@Override
void exit()
{
  PhysicsManager.stop();
  super.exit();
}
