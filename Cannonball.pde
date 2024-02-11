// Cannot be done as static final inside of cannonball, so we do it here in order to not
// load the model new whenever a new cannonball is being shot.
PShape cannonballShape;

/**
 * The cannonball is the projectile that should be aimed at the barrels in the sea.
 * The projectile carries an initial impulse that is applied when spawning (i.e. an
 * initial velocity, scaled by the designated mass of the cannonball, which is by
 * default one arbitrary unit). Every frame, gravity is applied to the projectile
 * as seen in {@link #move} after the projectile has moved according to its current
 * velocity.
 * Whenever the cannonball hits water or a target (or for that matter reaches an invalid Y-coordinate)
 * it gets invalidated and removed.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class Cannonball
{
  /**
   * The amount of units by which the cannonball (and thus gravitational force) is scaled up.
   */
  private static final float SCALE = 40f;
  
  /**
   * The cannonball's initial velocity.
   */
  private static final float CANNONBALL_VELOCITY = 2_000f;
  
  /**
   * The gravitational value.
   */
  private static final float GRAVITY = 9.81f;
  
  /**
   * The mass of the cannonball.
   */
  private static final float CANNONBALL_MASS = 1f;
  
  /**
   * The current position of the cannonball in 3d space.
   */
  private final PVector currentPosition;
  
  /**
   * The current velocity of the cannonball.
   */
  private final PVector currentVelocity;
  
  /**
   * Whether or not the cannonball is currently valid. If this value is set to false,
   * the ball gets removed.
   */
  private boolean valid = true;
  
  /**
   * Constructs a new cannonball, given the spawn position and the direction it is travelling in.
   *
   * @param position The starting position.
   * @param The initial velocity's yaw component.
   * @param The initial velocity's pitch component.
   */
  public Cannonball(PVector position, float yaw, float pitch)
  {
    currentPosition = position;
    
    float radiansYaw = radians(yaw);
    float radiansPitch = radians(-pitch);
    currentVelocity = new PVector(
      cos(radiansYaw) * cos(radiansPitch),
      sin(radiansPitch),
      sin(radiansYaw) * cos(radiansPitch));
      
    // It is important that we scale the velocity down with mass. This is proportional,
    // and higher mass means slower velocity, since this essentially acts like an impulse
    // when the cannonball is "created".
    currentVelocity.mult(CANNONBALL_VELOCITY / CANNONBALL_MASS);
  }
  
  /**
   * Updates the cannonball. Will draw its shape and update the position according to the
   * gravitational value and current velocity.
   */
  public void update()
  {
    pushMatrix();
    
    translate(currentPosition.x, currentPosition.y, currentPosition.z);
    scale(SCALE);
    
    shape(cannonballShape);
    
    popMatrix();
    
    if (currentPosition.y > 2500)
    {
      valid = false;
      return;
    }
    
    move();
  }
  
  /**
   * Moves the cannonball according to the current velocity and applies gravity.
   * Physics calculations are scaled up by the amount of which the cannonball is scaled up itself.
   */
  private void move()
  {
    // Moves the current object by the given current velocity, scaled by time.
    currentPosition.add(PVector.mult(currentVelocity, deltaTime));
    
    // We add the gravitational force to our current velocity each frame, multiplied by 40 since we scale up by 40.
    // Note that this also scales up our force by 40 to be accurate, otherwise gravity would be 1/40th.
    currentVelocity.add(0, GRAVITY * deltaTime * SCALE, 0);
  }
}
