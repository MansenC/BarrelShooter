import java.util.ArrayList;
import java.util.List;

/**
 * The cannon class handles control of the cannon. This includes rotating the cannon left/right and up/down.
 * This class also sets the camera position if not in freecam mode according to the cannon's position
 * and handles spawning the cannonballs.
 * Additionally, this also draws the UI overlay if the camera is not in freecam mode.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class Cannon
{
  /**
   * The minimum horizontal angle the cannon can shoot at.
   */
  private static final float CANNON_MIN_HORIZONTAL_ANGLE = -45f;
  
  /**
   * The maximum horizontal angle the cannon can shoot at.
   */
  private static final float CANNON_MAX_HORIZONTAL_ANGLE = 45f;
  
  /**
   * The minimum vertical angle the cannon can shoot at.
   */
  private static final float CANNON_MIN_VERTICAL_ANGLE = -5;
  
  /**
   * The maximum vertical angle the cannon can shoot at.
   */
  private static final float CANNON_MAX_VERTICAL_ANGLE = 85;
  
  /**
   * A list of all cannonballs currently shot. Will update every ball in the list,
   * and if the ball died, will remove them from the list.
   */
  private final List<Cannonball> balls = new ArrayList<Cannonball>();
  
  /**
   * The global position of the cannon.
   */
  private final PVector position;
  
  /**
   * The model for the cannon wagon.
   */
  private final PShape cannonWagon;
  
  /**
   * The model for the cannon barrel.
   */
  private final PShape cannon;
  
  /**
   * The current horizontal rotation of the cannon. In range of [-45..45].
   */
  private float cannonHorizontalRotation = 0;
  
  /**
   * The current vertical rotation of the cannon barrel. Controls how far the balls will shoot.
   * In range of [-15..85].
   */
  private float cannonVerticalRotation = CANNON_MIN_VERTICAL_ANGLE;
  
  /**
   * Constructs a new cannon instance at the provided world position.
   *
   * @param position The position of the cannon.
   */
  public Cannon(PVector position)
  {
    this.position = position;
    cannonWagon = loadShape("CannonWagon.obj");
    cannon = loadShape("Cannon.obj");
  }
  
  /**
   * Returns the vertical rotation of the cannon, used in the UI for displaying purposes.
   *
   * @returns The vertical cannon rotation.
   */
  public float getCannonVerticalRotation()
  {
    return cannonVerticalRotation;
  }
  
  /**
   * Renders the cannon and UI and updates the parameters according to user input.
   */
  public void update()
  {
    pushMatrix();
    
    // We move our cannon to the given position
    translate(position.x, position.y, position.z);
    rotateX(PI);
    rotateY(radians(cannonHorizontalRotation));
    
    // Only draw the wagon
    shape(cannonWagon);
    
    pushMatrix();
    
    // We need to rotate and translate the cannon so that the metal beam stays fixed in place
    // relative to its wagon.
    float radiansAngle = (cannonVerticalRotation - 90) * PI / 180;
    translate(sin(radiansAngle), 1 - cos(radiansAngle), 0);
    rotateZ(radiansAngle);
    
    // The scope should be on the upper side.
    rotateY(PI);
    shape(cannon);
    
    // If the left mouse button was pressed then we shoot a cannonball.
    // We do this here since we don't have to the transformation for spawning
    // the ball inside the barrel again.
    if (!paused && isMouseButtonPressed(LEFT) && !ui.isGameCompleted())
    {
      PVector ballSpawnLocation = new PVector(
        modelX(0, 3, 0),
        modelY(0, 3, 0),
        modelZ(0, 3, 0));
      balls.add(new Cannonball(ballSpawnLocation, cannonHorizontalRotation, cannonVerticalRotation));
      ui.removeBomb();
    }
    
    popMatrix();
    
    if (!camera.isFreecam())
    {
      handleUserInput();
      
      // Set the camera to a fixed point and rotate it with the cannon.
      camera.setYaw(cannonHorizontalRotation);
      camera.setPitch(25);
      camera.setPosition(
        modelX(-2, 4, 0),
        modelY(-2, 4, 0),
        modelZ(-2, 4, 0));
    }
    
    popMatrix();
    
    // We finally update all cannonballs.
    List<Cannonball> invalidatedBalls = new ArrayList<>();
    for (Cannonball ball : balls)
    {
      ball.update();
      if (ball.isValid())
      {
        continue;
      }
      
      invalidatedBalls.add(ball);
      
      // This check is done here since a ball may have hit a barrel
      // and is still valid, so checking right after shooting is
      // a bad idea or otherwise we lose if we only have one shot left.
      ui.checkGameOver();
    }
    
    balls.removeAll(invalidatedBalls);
  }
  
  /**
   * Handles the user's input for controlling the cannon. W turns the cannon up, S down,
   * A turns left, D turns right and left click shoots the cannon.
   */
  private void handleUserInput()
  {
    if (isKeyDown('w'))
    {
      cannonVerticalRotation += deltaTime * 10;
    }
    else if (isKeyDown('s'))
    {
      cannonVerticalRotation -= deltaTime * 10;
    }
    
    if (isKeyDown('a'))
    {
      cannonHorizontalRotation -= deltaTime * 10;
    }
    else if (isKeyDown('d'))
    {
      cannonHorizontalRotation += deltaTime * 10;
    }
    
    cannonVerticalRotation = constrain(cannonVerticalRotation, CANNON_MIN_VERTICAL_ANGLE, CANNON_MAX_VERTICAL_ANGLE);
    cannonHorizontalRotation = constrain(cannonHorizontalRotation, CANNON_MIN_HORIZONTAL_ANGLE, CANNON_MAX_HORIZONTAL_ANGLE);
  }
}
