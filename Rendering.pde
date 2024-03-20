import java.awt.AWTException;
import java.awt.Robot;

/**
 * The Camera class acts like our camera controller. In-game it is controlled by the movement of the cannon,
 * but during development it can be moved using WASD+Space+Shift and the mouse to inspect the environment.
 * In order to enable the debug camera, just change the constant for that to true.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class Camera
{
  /**
   * The movement speed of the camera.
   */
  private static final float MOVEMENT_SPEED = 0.25f;
  
  /**
   * The sensitivity factor. Increase this value for a <b>lower</b> sensitivity
   * and bring the value closer to 0 for a <b>higher</b> sensitivity.
   */
  private static final float MOUSE_SENSITIVITY_FACTOR = 5f;
  
  /**
   * This instance is used to control mouse locking to the screen center. May be null
   * if the executing operating system does not allow mouse control.
   */
  private final Robot robot;

  /**
   * The position in 3d space using a {@link PVector} to store the value.
   */
  private final PVector position;
  
  /**
   * The camera's yaw, unbound.
   */
  private float yaw = 0;
  
  /**
   * The camera's pitch, in range of [-80..80]
   */
  private float pitch = 0;
  
  /**
   * Whether or not the cursor should be locked to the screen center.
   */
  private boolean cursorLocked = false;
  
  /**
   * Whether or not the camera is in freecam mode, meaning not controlled by an actor.
   */
  private boolean freecam = false;

  /**
   * Constructs the camera instance with a given starting position. Constructs an AWT robot for mouse locking.
   *
   * @param position The starting position.
   */
  public Camera(PVector position)
  {
    this.position = position;
    
    Robot targetRobot;
    try
    {
      targetRobot = new Robot();
    }
    catch (AWTException ex)
    {
      targetRobot = null;
      System.err.println("Could not create robot instance: " + ex.getMessage());
    }
    
    robot = targetRobot;
  }
  
  /**
   * Returns the position of the camera.
   *
   * @return The camera position in world space.
   */
  public PVector getPosition()
  {
    return position;
  }
  
  /**
   * Updates the position to the newly provided one.
   *
   * @param x The new camera x position.
   * @param y The new camera y position.
   * @param z The new camera z position.
   */
  public void setPosition(float x, float y, float z)
  {
    this.position.set(x, y, z);
  }
  
  /**
   * Updates the yaw of the camera.
   *
   * @param yaw The new yaw.
   */
  public void setYaw(float yaw)
  {
    this.yaw = yaw;
  }
  
  /**
   * Updates the pitch of the camera.
   *
   * @param pitch The new pitch.
   */
  public void setPitch(float pitch)
  {
    this.pitch = pitch;
  }
  
  /**
   * Whether or not the camera is currently in freecam mode.
   *
   * True if the camera is in freecam mode.
   */
  public boolean isFreecam()
  {
    return freecam;
  }
  
  /**
   * Applies transformations so that (0|0|0) corresponds to the top-left of the user's screen
   * and (width|height|0) corresponds to the bottom-right.
   */
  public void applyGUITransformations()
  {
    // Calculate distance of UI plane based off screen height and FOV-Y.
    float targetDistance = height / (2 * tan(PI / 6));
    
    // Get the look direction, move it to the calculated distance and add the camera position.
    PVector lookDirection = getLookDirection();
    lookDirection.mult(targetDistance);
    lookDirection.add(position);
    
    // Now we translate in that direction so we always look at a fixed point where (0|0) is the center of the screen.
    translate(lookDirection.x, lookDirection.y, lookDirection.z);
    
    // We rotate the plane so it matches the camera's rotation.
    rotateY(-radians(yaw) - PI / 2);
    rotateX(radians(pitch));
    
    // And translate it to the top left so that (0|0) is the top-left corner and (width|height) is bottom-right.
    translate(-width / 2, -height / 2, 0);
  }

  /**
   * Handles camera position and rotation updates.
   */
  public void update()
  {
    // If we're in freecam mode then we allow movement however the camera controller wants it.
    if (freecam)
    {
      handleLookRotation();
      handleMovePosition();
    }
    
    // After we're done with the input, we want to be able to toggle freecam. This means that in the frame
    // where we toggle freecam we continue with the previously set position/rotation for the camera.
    
    // We toggle freecam with ctrl+f. 70 because that's the keyCode of f which gets stored
    // when ctrl is pressed down as well. The other condition is for the monsters who press
    // f first and then ctrl.
    if (isCombinationPressed(CONTROL, 70) || isCombinationPressed(CONTROL, 'f'))
    {
      freecam = !freecam;
    }
    
    // CTRL+P is used to pause/resume the game for inspection. We cannot change the paused
    // state when we're viewing the UI.
    if (!ui.isVisible() && (isCombinationPressed(CONTROL, 80) || isCombinationPressed(CONTROL, 'p')))
    {
      togglePaused();
    }
    
    if (isCombinationPressed(CONTROL, 88) || isCombinationPressed(CONTROL, 'x'))
    {
      ui.toggleVisibility();
    }
    
    // We convert our yaw/pitch into a look-direction on a unit sphere here.
    PVector lookDirection = getLookDirection();
    
    // We then offset this look-direction by the current position.
    lookDirection.add(position);
    
    // Why? Well because processing of course. The camera is handled by giving it a position and a position to look at.
    // How far away this position is doesn't really matter, but this is how we determine our camera rotation based on yaw/pitch.
    camera(
      position.x,
      position.y,
      position.z,
      lookDirection.x,
      lookDirection.y,
      lookDirection.z,
      0,
      1, // I absolutely hate that y is flipped through this...
      0);

    perspective(PI / 3, ((float) width) / height, 0.1, 10_000_000);
    
    // Finally, we lock the cursor to the screen if we should.
    lockCursor();
  }
  
  /**
   * Locks or unlocks the cursor to the screen.
   *
   * @param locked Whether or not the cursor should be locked now.
   */
  public void setCursorLocked(boolean locked)
  {
    cursorLocked = locked;
    if (locked)
    {
      noCursor();
    }
    else
    {
      cursor(ARROW);
    }
  }
  
  /**
   * Returns the vector of the direction that the camera is currently looking towards. The magnitude of this vector is 1.
   *
   * @returns The direction the camera is looking towards.
   */
  private PVector getLookDirection()
  {
    float radiansYaw = radians(yaw);
    float radiansPitch = radians(pitch);
    return new PVector(
      cos(radiansYaw) * cos(radiansPitch),
      sin(radiansPitch),
      sin(radiansYaw) * cos(radiansPitch));
  }
  
  /**
   * Handles the modification of both yaw and pitch variables.
   */
  private void handleLookRotation()
  {
    int previousMouseX;
    int previousMouseY;
    if (!isLocked())
    {
      // When the robot doesn't exist or we do not lock the cursor then we do not have to worry about how the mouse locking
      // regarding camera movement.
      previousMouseX = pmouseX;
      previousMouseY = pmouseY;
    }
    else
    {
      // If it is there, however, using pmouseX/Y will not working. This is because the mouse position
      // will always jump back to the origin, thus we cannot turn at all. We just use the screen center
      // as a reference point for mouse movement then.
      previousMouseX = displayWidth / 2;
      previousMouseY = displayHeight / 2;
    }
    
    if (pmouseX != 0)
    {
      // We do not care about rolling over.
      yaw += (mouseX - previousMouseX) / MOUSE_SENSITIVITY_FACTOR;
    }
    
    if (pmouseY != 0)
    {
      // We do not want to roll over here, we clamp pitch from [-80..80]. Well, constrain. But why not break some conventions, let's go.
      pitch += (mouseY - previousMouseY) / MOUSE_SENSITIVITY_FACTOR;
      pitch = constrain(pitch, -80, 80);
    }
  }
  
  /**
   * Handles the input of the keyboard in order to move the camera.
   */
  private void handleMovePosition()
  {
    if (isKeyDown('w'))
    {
      moveCameraInDirection(yaw);
    }
    else if (isKeyDown('s'))
    {
      moveCameraInDirection(yaw + 180);
    }
    
    if (isKeyDown('a'))
    {
      moveCameraInDirection(yaw - 90);
    }
    else if (isKeyDown('d'))
    {
      moveCameraInDirection(yaw + 90);
    }
    
    if (isKeyDown(' '))
    {
      // Remember, processing inverted the Y coordinate
      position.add(new PVector(0, -MOVEMENT_SPEED, 0));
    }
    else if (isKeyDown(SHIFT))
    {
      position.add(new PVector(0, MOVEMENT_SPEED, 0));
    }
  }
  
  /**
   * Moves the camera in the direction of the provided yaw angle.
   *
   * @param yawDirection The direction to move the camera towards.
   */
  private void moveCameraInDirection(float yawDirection)
  {
    float radiansYaw = radians(yawDirection);
    PVector moveDirection = new PVector(cos(radiansYaw), 0, sin(radiansYaw));
    
    moveDirection.mult(MOVEMENT_SPEED);
    position.add(moveDirection);
  }
  
  /**
   * Locks the cursor to the center screen, if {@link #robot} is not null and {@link #cursorLocked} is true.
   */
  private void lockCursor()
  {
    if (!isLocked())
    {
      return;
    }
    
    // We lock the cursor to the center.
    robot.mouseMove(displayWidth / 2, displayHeight / 2);
  }
  
  /**
   * Checks if the mouse is currently locked. This condition is true when the cursor is requested to be locked,
   * the application is focused (so we can use the mouse outside the window if unfocused) and if the robot
   * is set, otherwise locked does not work.
   *
   * @returns Whether or not the cursor is currently locked.
   */
  private boolean isLocked()
  {
    return cursorLocked && focused && robot != null;
  }
}
