// Cannot be done as static final inside of cannonball, so we do it here in order to not
// load the model new whenever a new cannonball is being shot.
PShape cannonballShape;

float cannonballWeight = CANNONBALL_WEIGHT_DEFAULT;
float cannonballForce = CANNONBALL_FORCE_DEFAULT;

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
    rigidbody = new Rigidbody(cannonballShape, new SphereCollisionShape(.4f), position);
    rigidbody.setMass(cannonballWeight);
    
    PhysicsManager.registerRigidbody(rigidbody);
    
    float radiansYaw = radians(yaw);
    float radiansPitch = radians(-pitch);
    PVector initialImpulse = new PVector(
      cos(radiansYaw) * cos(radiansPitch),
      sin(radiansPitch),
      sin(radiansYaw) * cos(radiansPitch));
      
    initialImpulse.mult(cannonballForce);
    rigidbody.addForce(initialImpulse);
  }
  
  public boolean isValid()
  {
    return valid;
  }
  
  /**
   * Updates the cannonball. Will draw its shape and update the position according to the
   * gravitational value and current velocity.
   */
  public void update()
  {
    if (rigidbody.getPosition().y < 30)
    {
      rigidbody.draw();
      return;
    }
    
    valid = false;
    PhysicsManager.removeRigidbody(rigidbody);
  }
}
