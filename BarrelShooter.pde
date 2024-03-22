// We keep our global variables here. These are kept to a minimum since I personally detest the usage of those.
// Every global variable represents a class instance that handles a certain part of the rendering or processing pipeline.
Camera camera;
Environment environment;
Cannon cannon;
BarrelManager barrelManager;
UI ui;

// This is the time of the last frame, as dictated by millis()
int lastFrameMillis;
// The deltaTime is in seconds, measured to the last frame.
float deltaTime;

// These variables are used for pausing, mostly for pausing the physics thread.
static final Object PAUSE_LOCK = new Object();
static volatile boolean paused = false;

// We keep the frameTime separate and don't use millis() in order to factor
// in pauses.
long frameTime = 0;

/**
 * Toggles the paused state of the game. Pausing means no updates to the environment or physics
 * updates.
 */
public void togglePaused()
{
  if (!paused)
  {
    paused = true;
    return;
  }
  
  // We notify the pause-lock so that the physics thread is woken up from its wait.
  synchronized (PAUSE_LOCK)
  {
    paused = false;
    PAUSE_LOCK.notifyAll();
  }
}

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
  ui = new UI();
  camera = new Camera(new PVector(-41.75f, 9.05f, 3.33f));
  environment = new Environment();
  cannon = new Cannon(new PVector(-30, 10.4f, 3.33f));
  barrelManager = new BarrelManager(new PVector(-30, 10.4f, 3.33f));
  
  camera.setCursorLocked(true);
  
  // Load external global variables :)
  barrelShape = loadShape("Barrel.obj");
  hitIndicator = loadShape("HitIndicator.obj");
  cannonballShape = loadShape("Cannonball.obj");
  
  // We finally spawn our barrels.
  barrelManager.spawnBarrels(BARREL_AMOUNT_DEFAULT);
}

/**
 * The core loop for this program. Handles rendering and everything else.
 */
void draw()
{
  // First re-enabling and at the end of draw disabling the depth test fixes the UI being drawn
  // behind the environment in some cases. This is super weird but required.
  hint(ENABLE_DEPTH_TEST);
  background(0);
  
  // We calculate the delta time in seconds.
  int now = millis();
  if (paused)
  {
    deltaTime = 0f;
  }
  else
  {
    deltaTime = (now - lastFrameMillis) / 1000f;
    frameTime += now - lastFrameMillis;
  }
  
  lastFrameMillis = now;
  
  // First we handle the environment. This includes lighting.
  environment.update();
  
  // Then it's time for the barrels and cannon.
  barrelManager.update();
  cannon.update();
  
  // And then we update our camera, process the input and update the position.
  camera.update();
  
  // After that we draw the minigame GUI. The reason why it's last is simply that
  // any objects drawn beforehand would get rendered above the UI layer.
  ui.drawMinigameGUI();
  
  // Finally we clean up our key and mouse data for this frame.
  framePressedKeys.clear();
  framePressedMouseButtons.clear();
  
  // Again, we disable the depth test for the settings UI.
  hint(DISABLE_DEPTH_TEST);
  noLights();
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
  if (paused)
  {
    togglePaused();
  }
  
  PhysicsManager.stop();
  super.exit();
}
