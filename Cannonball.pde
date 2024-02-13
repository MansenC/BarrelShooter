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
   * The cannonball's initial velocity.
   */
  private static final float CANNONBALL_VELOCITY = 1_400f;
  
  /**
   * The gravitational value.
   */
  private static final float GRAVITY = 9.81f;
  
  /**
   * The rigidbody that takes over the calculations for our physics.
   */
  private final Rigidbody rigidbody;
  
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
    rigidbody = new Rigidbody(cannonballShape, position);
    rigidbody.setUseGravity();
    
    float radiansYaw = radians(yaw);
    float radiansPitch = radians(-pitch);
    PVector initialImpulse = new PVector(
      cos(radiansYaw) * cos(radiansPitch),
      sin(radiansPitch),
      sin(radiansYaw) * cos(radiansPitch));
      
    initialImpulse.mult(CANNONBALL_VELOCITY);
    rigidbody.addForce(initialImpulse);
  }
  
  /**
   * Updates the cannonball. Will draw its shape and update the position according to the
   * gravitational value and current velocity.
   */
  public void update()
  {
    if (rigidbody.getPosition().y > 2100)
    {
      rigidbody.setKinematic(false);
    }
    
    rigidbody.draw();
  }
}
