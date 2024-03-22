import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * The framerate of physics updates, in this case 50fps. This is the frame
 * time in milliseconds.
 */
public static final float PHYSICS_DELTA = 1f / 50;

/**
 * We cannot really rely on processing for a consistent framerate, can we. This is
 * why the physics manager exists, it spins up a new thread that runs at 50FPS and
 * updates physics according to that framerate, so that no weird behavior occurs
 * with the framerate.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public static class PhysicsManager
{
  /**
   * Whether or not the physics are updated or not.
   */
  private static volatile boolean running = true;
  
  /**
   * An instance to the collision manager. This separate class handles the calculation of
   * collisions for all rigidbodies registered here..
   */
  private static final CollisionManager COLLISION_MANAGER = new CollisionManager();
  
  /**
   * A list of all active rigidbodies that need updating. We cannot use a simple
   * ArrayList here since the list may get updated during updates to our physics.
   * This is why we use java's concurrent list type.
   */
  private static final List<Rigidbody> RIGIDBODIES = new CopyOnWriteArrayList<>();
  
  /**
   * A private constructor to mark this as a static class (C#-like, not java-like).
   */
  private PhysicsManager()
  {
    // NOP
  }
  
  /**
   * Starts a new thread which runs our physics.
   */
  public static void start()
  {
    // We tell the thread that its method to execute is runPhysics.
    Thread physicsThread = new Thread(PhysicsManager::runPhysics);
    
    // Set a new name to the thread so we can identify it.
    physicsThread.setName("PhysicsHandler");
    
    // Sets the thread as a daemon, meaning when the main thread dies
    // it dies as well.
    physicsThread.setDaemon(true);
    
    // Actually start the thread.
    physicsThread.start();
  }
  
  /**
   * Stops physics execution.
   */
  public static void stop()
  {
    running = false;
  }
  
  /**
   * Registers a given rigidbody to the physics engine and will schedule updates.
   */
  public static void registerRigidbody(Rigidbody rigidbody)
  {
    synchronized(RIGIDBODIES)
    {
      RIGIDBODIES.add(rigidbody);
    }
  }
  
  /**
   * Removes a given rigidbody from the physics engine.
   */
  public static void removeRigidbody(Rigidbody rigidbody)
  {
    synchronized (RIGIDBODIES)
    {
      RIGIDBODIES.remove(rigidbody);
    }
  }
  
  /**
   * Executes the physics loop.
   */
  private static void runPhysics()
  {
    // We store the time before physics execution in order to calculate the exact time we have
    // to wait.
    long beforeExecutionTime;
    while (running)
    {
      // First of all we check whether or not this thread shoult be paused.
      synchronized (PAUSE_LOCK)
      {
        if (paused)
        {
          try
          {
            // We wait until the pause lock is notified by the main thread.
            PAUSE_LOCK.wait();
          }
          catch (InterruptedException ex)
          {
            ex.printStackTrace();
            Thread.currentThread().interrupt();
          }
          
          // And if we're paused and not running anymore then we just quit immediately.
          if (!running)
          {
            break;
          }
        }
      }
      
      beforeExecutionTime = System.currentTimeMillis();
      updateRigidbodies();
      
      // We essentially measure the time it took to update our rigidbodies here.
      // We then subtract this time from our PHYSICS_DELTA so we can get an accurate measure
      // on how long we have to wait. If updating took 2ms and we ordinarily wait 20ms then
      // we now just wait 18ms instead to keep up.
      long sleepDelta = ((long) (PHYSICS_DELTA * 1000)) - (System.currentTimeMillis() - beforeExecutionTime);
      if (sleepDelta <= 0)
      {
        // If we're running late (i.e. the physics took more than 20ms) then we continue
        // immediately with the next update.
        continue;
      }
      
      try
      {
        // Actually sleep.
        Thread.sleep(sleepDelta);
      }
      catch (InterruptedException ex)
      {
        ex.printStackTrace();
        
        // It is good practice to interrupt the running thread if the wait was interrupted.
        Thread.currentThread().interrupt();
      }
    }
  }
  
  /**
   * Updates all rigidbodies in steps.
   */
  private static void updateRigidbodies()
  {
    // First step: Collision.
    COLLISION_MANAGER.detectCollisions();
    
    // Second step: integrate the forces of our rigidbodies
    for (Rigidbody rigidbody : RIGIDBODIES)
    {
      rigidbody.integrateForces();
    }
    
    // Third step: Update the rigidbodies' positions
    for (Rigidbody rigidbody : RIGIDBODIES)
    {
      rigidbody.integrate();
    }
  }
}

/**
 * Based on broadphase detection aka each body is checked against each body. This implementation
 * is fine for the amount of shapes and shape types we are expecting.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public static class CollisionManager
{
  /**
   * A minimum distance factor for a valid collision.
   */
  private static final float COLLISION_EPSILON = 1e-4f;
  
  /**
   * The maximum amount of iterations for a single collision check.
   */
  private static final int MAX_ITERATIONS = 34;
  
  /**
   * Whether or not to swap the order of rigidbody collision comparison.
   */
  private boolean swapOrder = false;
  
  /**
   * The main entry point to detect collisions between all registered rigidbodies.
   * This is an O(n²) operation, comparing every rigidbody to every other rigidbodies.
   */
  public void detectCollisions()
  {
    synchronized (PhysicsManager.RIGIDBODIES)
    {
      for (int base = 0; base < PhysicsManager.RIGIDBODIES.size(); base++)
      {
        for (int compare = base + 1; compare < PhysicsManager.RIGIDBODIES.size(); compare++)
        {
          if (swapOrder)
          {
            detectRigidbodyCollision(
              PhysicsManager.RIGIDBODIES.get(base),
              PhysicsManager.RIGIDBODIES.get(compare));
          }
          else
          {
            detectRigidbodyCollision(
              PhysicsManager.RIGIDBODIES.get(compare),
              PhysicsManager.RIGIDBODIES.get(base));
          }
          
          swapOrder = !swapOrder;
        }
      }
    }
  }
  
  /**
   * Attempts to detect a collision between two rigidbodies using the basis
   * of xenocollide and the minkowski difference collision algorithm.
   *
   * @param first The first rigidbody.
   * @param second The second rigidbody.
   */
  private void detectRigidbodyCollision(Rigidbody first, Rigidbody second)
  {
    // I'm not going to implement speculative collision detection since we want to stay
    // accurate. So we're just detecting raw collisions here.
    // For more information on the collision detection, refer to
    // https://xbdev.net/misc_demos/demos/minkowski_difference_collisions/paper.pdf
    // and http://xenocollide.snethen.com/
    
    PVector v01 = first.getPosition().copy();
    PVector v02 = second.getPosition().copy();
    
    // v0 is the center of the minkowski difference
    PVector v0 = PVector.sub(v02, v01);
    if (v0.magSq() < EPSILON * EPSILON)
    {
      // We avoid cases where the center overlaps. Direction doesn't matter.
      v0 = new PVector(0.00001f, 0, 0);
    }
    
    PVector normal = PVector.mult(v0, -1);
    
    PVector v11 = supportMapTransformed(first, v0);
    PVector v12 = supportMapTransformed(second, normal);
    PVector v1 = PVector.sub(v12, v11);
    
    if (v1.dot(normal) <= 0f)
    {
      // No collision - we return.
      return;
    }
    
    normal = v1.cross(v0);
    if (normal.magSq() < EPSILON * EPSILON)
    {
      // We have a collision!
      normal = PVector.sub(v1, v0).normalize();
      
      PVector point = v11.copy().add(v12).mult(0.5f);
      float penetration = PVector.sub(v12, v11).dot(normal);
      
      collisionDetected(first, second, point, normal, penetration);
      return;
    }
    
    PVector v21 = supportMapTransformed(first, PVector.mult(normal, -1));
    PVector v22 = supportMapTransformed(second, normal);
    PVector v2 = PVector.sub(v22, v21);
    
    if (v2.dot(normal) <= 0f)
    {
      return;
    }
    
    // Determine whether origin is on + or - side of plane (v1,v0,v2)
    normal = PVector.sub(v1, v0).cross(PVector.sub(v2, v0));
    
    // If the origin is on the - side of the plane, reverse the direction of the plane
    if (normal.dot(v0) > 0f)
    {
      swap(v1, v2);
      swap(v11, v21);
      swap(v12, v22);
      normal.mult(-1);
    }
    
    int phase1 = 0;
    int phase2 = 0;
    boolean hit = false;
    
    PVector point = new PVector();
    float penetration = 0;
    
    // Phase 1: identify a portal
    while (phase1++ < MAX_ITERATIONS)
    {
      // Obtain the support point in a direction perpendicular to the existing plane
      // Note: This point is guaranteed to lie off the plane
      PVector v31 = supportMapTransformed(first, PVector.mult(normal, -1));
      PVector v32 = supportMapTransformed(second, normal);
      PVector v3 = PVector.sub(v32, v31);
      
      if (v3.dot(normal) <= 0f)
      {
        return;
      }
      
      // If origin is outside (v1,v0,v3), then eliminate v2 and loop
      if (v1.cross(v3).dot(v0) < 0f)
      {
        v2 = v3;
        v21 = v31;
        v22 = v32;
        
        normal = PVector.sub(v1, v0).cross(PVector.sub(v3, v0));
        continue;
      }
      
      // If origin is outside (v3,v0,v2), then eliminate v1 and loop
      if (v3.cross(v2).dot(v0) < 0f)
      {
        v1 = v3;
        v11 = v31;
        v12 = v32;
        
        normal = PVector.sub(v3, v0).cross(PVector.sub(v2, v0));
        continue;
      }
      
      // Phase two: refine the portal - we are now inside of a wedge.
      while (true)
      {
        phase2++;
        
        // Compute normal of the wedge face
        normal = PVector.sub(v2, v1).cross(PVector.sub(v3, v1));
        
        // Just for good measure. If the normal is near-zero then we basically
        // are on the plane.
        if (normal.magSq() < EPSILON * EPSILON)
        {
          collisionDetected(first, second, point, normal, penetration);
          return;
        }
        
        normal.normalize();
        
        // If the origin is inside the wedge, we have a hit
        if (!hit && normal.dot(v1) >= 0)
        {
          hit = true;
        }
        
        // Find the support point in the direction of the wedge face
        PVector v41 = supportMapTransformed(first, PVector.mult(normal, -1));
        PVector v42 = supportMapTransformed(second, normal);
        PVector v4 = PVector.sub(v42, v41);
        
        float delta = PVector.sub(v4, v3).dot(normal);
        penetration = v4.dot(normal);
        
        if (delta <= COLLISION_EPSILON || penetration <= 0 || phase2 > MAX_ITERATIONS)
        {
          if (!hit)
          {
            return;
          }
          
          float b0 = v1.cross(v2).dot(v3);
          float b1 = v3.cross(v2).dot(v0);
          float b2 = v0.cross(v1).dot(v3);
          float b3 = v2.cross(v1).dot(v0);
          
          float sum = b0 + b1 + b2 + b3;
          if (sum <= 0)
          {
            b0 = 0;
            b1 = v2.cross(v3).dot(normal);
            b2 = v3.cross(v1).dot(normal);
            b3 = v1.cross(v2).dot(normal);
            
            sum = b1 + b2 + b3;
          }
          
          float inverse = 1f / sum;
          point = v01.mult(b0);
          point.add(v11.mult(b1));
          point.add(v21.mult(b2));
          point.add(v31.mult(b3));
          
          point.add(v02.mult(b0));
          point.add(v12.mult(b1));
          point.add(v22.mult(b2));
          point.add(v32.mult(b3));
          
          point.mult(inverse / 2f);
          collisionDetected(first, second, point, normal, penetration);
          return;
        }
        
        // Compute the tetrahedron dividing face (v4,v0,v3)
        PVector temp1 = v4.cross(v0);
        float dot = temp1.dot(v1);
        if (dot >= 0f)
        {
          dot = temp1.dot(v2);
          if (dot >= 0f)
          {
            // Inside d1 and inside d2 => eliminate v1
            v1 = v4;
            v11 = v41;
            v12 = v42;
            continue;
          }
          
          // Inside d1 and outside d2 => eliminate v3
          v3 = v4;
          v31 = v41;
          v32 = v42;
          continue;
        }
        
        dot = temp1.dot(v3);
        if (dot >= 0f)
        {
          // Outside d1 and inside d3 => eliminate v2
          v2 = v4;
          v21 = v41;
          v22 = v42;
          continue;
        }
        
        // Outside d1 and outside d3 => eliminate v1
        v1 = v4;
        v11 = v41;
        v12 = v42;
      }
    }
  }
  
  /**
   * Transforms the given support mapping for a rigidbody to the world orientation of the rigidbody
   * itself.
   *
   * @param rigidbody The rigidbody.
   * @param direction The direction to transform the support mapping towards.
   * @returns The transformed support mapping.
   */
  private PVector supportMapTransformed(
    Rigidbody rigidbody,
    PVector direction)
  {
    Matrix3x3 orientation = rigidbody.getOrientation();
    
    PVector result = new PVector(
      direction.x * orientation.m00 + direction.y * orientation.m01 + direction.z * orientation.m02,
      -(direction.x * orientation.m10 + direction.y * orientation.m11 + direction.z * orientation.m12),
      direction.x * orientation.m20 + direction.y * orientation.m21 + direction.z * orientation.m22);
    
    rigidbody.getCollisionShape().getSupportMapping(result);
    
    result = orientation.transform(result);
    result.add(rigidbody.getPosition());
    return result;
  }
  
  /**
   * This function handles whenever a collision has been detected. Calculates the impulse applied to
   * both rigidbodies based on the velocity, angular velocity and point of contact.
   *
   * @param first The first rigidbody.
   * @param second The second rigidbody.
   * @param point The world position of the collision point.
   * @param normal The normal direction of the collision.
   * @param penetration How deep the collision penetrates the surface of the first rigidbody.
   */
  private void collisionDetected(
    Rigidbody first,
    Rigidbody second,
    PVector point,
    PVector normal,
    @SuppressWarnings("unused") float penetration)
  {
    // Point is global, normal relative to point
    // For implementation, see https://en.wikipedia.org/wiki/Collision_response#Computing_impulse-based_reaction
    // We assume the coefficient of restitution is 1, therefor no friction losses.
    
    // Also inertia tensors may be world-relative!
    PVector firstCollisionDirection = PVector.sub(point, first.getPosition());
    PVector secondCollisionDirection = PVector.sub(point, second.getPosition());
    
    // This calculates the pre-collision velocities at the point of contact for each rigidbody.
    PVector firstCollisionVelocity = PVector.add(first.getVelocity(), first.getAngularVelocity().cross(firstCollisionDirection));
    PVector secondCollisionVelocity = PVector.add(second.getVelocity(), second.getAngularVelocity().cross(secondCollisionDirection));
    
    PVector relativeVelocity = PVector.sub(secondCollisionVelocity, firstCollisionVelocity);
    
    PVector relativeInertia = first.getInverseInertia().transform(firstCollisionDirection.cross(normal)).cross(firstCollisionDirection);
    relativeInertia.add(second.getInverseInertia().transform(secondCollisionDirection.cross(normal)).cross(secondCollisionDirection));
    
    float inertiaScale = relativeInertia.dot(normal);
    float magnitudeDenominator = first.getInverseMass() + second.getInverseMass() + inertiaScale;
    
    float impulseMagnitude = PVector.mult(relativeVelocity, -2).dot(normal) / magnitudeDenominator;
    PVector impulseVector = PVector.mult(normal, impulseMagnitude);
    
    // Newton's third law here.
    second.addImpulseAtPoint(impulseVector, point);
    first.addImpulseAtPoint(impulseVector.mult(-1), point);
    
    second.onHit();
    first.onHit();
  }
  
  /**
   * Swaps two PVector values.
   *
   * @param one The first vector.
   * @param two The second vector.
   */
  private static void swap(PVector one, PVector two)
  {
    float x = one.x;
    float y = one.y;
    float z = one.z;
    
    one.x = two.x;
    one.y = two.y;
    one.z = two.z;
    two.x = x;
    two.y = y;
    two.z = z;
  }
}

/**
 * The collision shape is the base class for any shape used for collision detection.
 * We define two standardized shapes that define known support mappings and inertia
 * and mass values.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public abstract class CollisionShape
{
  /**
   * The standardized moment of inertia for the given collision shape.
   */
  protected Matrix3x3 inertia;
  
  /**
   * The mass of this collision shape for when the volume equals to 1.
   */
  protected float mass;
  
  /**
   * Calculates the support mapping as used in the collision detection
   * algorithm with the provided direction and stores the result
   * in the provided vector.
   *
   * @param direction The direction for the mapping, as well as the resulting value.
   */
  public abstract void getSupportMapping(PVector direction);
  
  /**
   * Calculates the mass and inertia values for the collision shape.
   */
  public abstract void calculateMassInertia();
  
  /**
   * Returns the moment of inertia for the collision shape.
   *
   * @returns The moment of inertia.
   */
  public Matrix3x3 getInertia()
  {
    return inertia;
  }
  
  /**
   * Returns the standard mass for this shape.
   *
   * @returns The standard mass.
   */
  public float getMass()
  {
    return mass;
  }
}

/**
 * The collision shape for a perfect sphere of a given radius.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class SphereCollisionShape extends CollisionShape
{
  /**
   * The radius of the sphere.
   */
  private final float radius;
  
  /**
   * Constructs the sphere collision shape with the provided radius.
   *
   * @param radius The target radius for this shape.
   */
  public SphereCollisionShape(float radius)
  {
    this.radius = radius;
    calculateMassInertia();
  }
  
  @Override
  public void getSupportMapping(PVector direction)
  {
    direction.normalize();
    direction.mult(radius);
  }
  
  @Override
  public void calculateMassInertia()
  {
    mass = (4f / 3f) * PI * radius * radius * radius;
    
    inertia = new Matrix3x3();
    inertia.m00 = 0.4f * mass * radius * radius;
    inertia.m22 = inertia.m11 = inertia.m00;
  }
}

/**
 * The collision shape for a perfect cylinder of a given base radius and height.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class CylinderShape extends CollisionShape
{
  /**
   * The height of this cylinder.
   */
  private final float height;
  
  /**
   * The radius of the base of this cylinder.
   */
  private final float radius;
  
  /**
   * Constructs the cylinder collision shape with the provided height radius.
   *
   * @param height The height of this cylinder.
   * @param radius The target base radius for this cylinder.
   */
  public CylinderShape(float height, float radius)
  {
    this.height = height;
    this.radius = radius;
    calculateMassInertia();
  }
  
  @Override
  public void getSupportMapping(PVector direction)
  {
    float resultX;
    float resultY;
    float resultZ;
    
    float sigma = sqrt(direction.x * direction.x + direction.z * direction.z);
    if (sigma > 0f)
    {
      resultX = direction.x / sigma * radius;
      resultY = Math.signum(direction.y) * height / 2f;
      resultZ = direction.z / sigma * radius;
    }
    else
    {
      resultX = 0f;
      resultY = Math.signum(direction.y) * height / 2f;
      resultZ = 0f;
    }
    
    direction.set(resultX, resultY, resultZ);
  }
  
  @Override
  public void calculateMassInertia()
  {
    mass = PI * radius * radius * height;
    
    inertia = new Matrix3x3();
    inertia.m00 = (1f / 4f) * mass * radius * radius + (1f / 12f) * mass * height * height;
    inertia.m11 = (1f / 2f) * mass * radius * radius;
    inertia.m22 = inertia.m00;
  }
}

/**
 * A 3d rigidbody implementation. Uses moment of inertia, force and torque to calculate its new position
 * based on a fixed time step interval.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class Rigidbody
{
  /**
   * The gravitational force for this project.
   */
  public static final float GRAVITY_ACCELERATION = 9.81f;
  
  /**
   * A list of all shapes attached to this rigidbody.
   */
  private final List<PShape> meshes = new CopyOnWriteArrayList<>();
  
  /**
   * The collision shape for this rigidbody.
   */
  private final CollisionShape collisionShape;
  
  /**
   * The global position of this rigidbody.
   */
  protected final PVector position;
  
  /**
   * The current orientation of this rigidbody represented as a rotation matrix.
   */
  private final Matrix3x3 orientation = new Matrix3x3();
  
  /**
   * The moment of inertia for the given rigidbody shape.
   */
  private Matrix3x3 inertia;
  
  /**
   * The inverse of the moment of inertia.
   */
  private Matrix3x3 inverseInertia;
  
  /**
   * The inverse of the orientation.
   */
  private Matrix3x3 inverseOrientation = new Matrix3x3();
  
  /**
   * The inverse of the moment of inertia transformed to world space.
   */
  private Matrix3x3 inverseInertiaWorld = new Matrix3x3();
  
  /**
   * The current accumulated force to be applied in the next timestep.
   */
  protected final PVector force = new PVector();
  
  /**
   * The current accumulated torque to be applied in the next timestep.
   */
  protected final PVector torque = new PVector();
  
  /**
   * The current linear velocity of this rigidbody.
   */
  private final PVector linearVelocity = new PVector();
  
  /**
   * The current angular velocity of this rigidbody.
   */
  private final PVector angularVelocity = new PVector();
  
  /**
   * Whether or not this rigidbody is kinematic.
   */
  private boolean kinematic = true;
  
  /**
   * Whether or not gravity applies to this rigidbody.
   */
  private boolean gravity = true;
  
  /**
   * The inverse mass of this rigidbody. Stored as the inverse for easier calculations.
   */
  protected float inverseMass = 1f;
  
  /**
   * The amount of damping per time step on the linear velocity.
   */
  private float linearDamping = 0f;
  
  /**
   * The amount of damping per time step on the angular velocity.
   */
  private float angularDamping = 0f;
  
  /**
   * Constructs a new rigidbody instance based on the provided mesh, collision shape and
   * its global position.
   *
   * @param mesh The mesh to display at the position/rotation of this rigidbody.
   * @param collisionShape The target shape of this rigidbody.
   * @param position The global initial position.
   */
  public Rigidbody(PShape mesh, CollisionShape collisionShape, PVector position)
  {
    meshes.add(mesh);
    this.collisionShape = collisionShape;
    
    this.position = position;
    
    inertia = collisionShape.getInertia();
    inverseInertia = inertia.inverse();
    inverseMass = 1f / collisionShape.getMass();
  }
  
  /**
   * Adds a child mesh to this rigidbody.
   *
   * @param mesh The mesh to add.
   */
  public void addChildMesh(PShape mesh)
  {
    meshes.add(mesh);
  }
  
  /**
   * Sets whether or not the rigidbody is kinematic and receives updated based on the forces applied.
   *
   * @param kinematic Whether or not the rigidbody is kinematic.
   */
  public void setKinematic(boolean kinematic)
  {
    this.kinematic = kinematic;
  }
  
  /**
   * Provides the collision shape of this rigidbody.
   *
   * @returns The collision shape.
   */
  public CollisionShape getCollisionShape()
  {
    return collisionShape;
  }
  
  /**
   * Provides the inverse mass of this rigidbody.
   *
   * @returns The inverse mass.
   */
  public float getInverseMass()
  {
    return inverseMass;
  }
  
  /**
   * Provides the global position of this rigidbody.
   *
   * @returns The global position.
   */
  public PVector getPosition()
  {
    return position;
  }
  
  /**
   * Provides the velocity of this rigidbody.
   *
   * @returns The velocity.
   */
  public PVector getVelocity()
  {
    return linearVelocity;
  }
  
  /**
   * Provides the angular velocity of this rigidbody.
   *
   * @returns The angular velocity.
   */
  public PVector getAngularVelocity()
  {
    return angularVelocity;
  }
  
  /**
   * Provides the inverse inertia of this rigidbody.
   *
   * @returns The inverse inertia.
   */
  public Matrix3x3 getInverseInertia()
  {
    return inverseInertia;
  }
  
  /**
   * Provides the orientation of this rigidbody.
   *
   * @returns The orientation.
   */
  public Matrix3x3 getOrientation()
  {
    return orientation;
  }
  
  /**
   * Updates the mass of this rigidbody to the provided value. Will update the moment of inertia as well.
   *
   * @param mass The new mass of this rigidbody.
   */
  public void setMass(float mass)
  {
    inertia = collisionShape.getInertia().mult(mass / collisionShape.getMass());
    inverseInertia = inertia.inverse();
    inverseMass = 1f / mass;
  }
  
  /**
   * Adds a force to this rigidbody that will be applied in the next time step.
   *
   * @param force The force to apply.
   */
  public synchronized void addForce(PVector force)
  {
    this.force.add(force);
  }
  
  /**
   * Adds a torque to this rigidbody that will be applied in the next time step.
   *
   * @param torque The torque to apply.
   */
  public synchronized void addTorque(PVector torque)
  {
    this.torque.add(torque);
  }
  
  /**
   * Adds a force to this rigidbody that originates at the provided point in world space.
   * This results in a torque being applied to this rigidbody.
   *
   * @param force The force to apply.
   * @param point The point in world space where the force originates.
   */
  public synchronized void addForceAtPoint(PVector force, PVector point)
  {
    this.force.add(force);
    
    point.sub(position);
    torque.add(point.cross(force));
  }
  
  /**
   * Adds an impulse to this rigidbody that originates at the provided point in world space.
   * This results in a torque being applied to this rigidbody.
   *
   * @param impulse The impulse to apply.
   * @param point The point in world space where the impulse originates.
   */
  public synchronized void addImpulseAtPoint(PVector impulse, PVector point)
  {
    linearVelocity.add(PVector.mult(impulse, inverseMass));
    
    PVector relativePosition = PVector.sub(point, position);
    angularVelocity.add(inverseInertiaWorld.transform(relativePosition.cross(impulse)));
  }
  
  /**
   * Transforms a point that is relative to this rigidbody to world space.
   *
   * @param localPosition The local position to transform.
   * @returns A transformed position based on the position and rotation of this rigidbody.
   */
  public PVector transformLocalPosition(PVector localPosition)
  {
    PVector rotatedPosition = orientation.transform(localPosition);
    return rotatedPosition.add(position);
  }
  
  /**
   * Sets the linear damping applied to this rigidbody.
   *
   * @param damping The damping factor, between 0 and 1, where 0 means no damping.
   */
  public void setLinearDamping(float damping)
  {
    linearDamping = damping;
  }
  
  /**
   * Sets the angular damping applied to this rigidbody.
   *
   * @param damping The damping factor, between 0 and 1, where 0 means no damping.
   */
  public void setAngularDamping(float damping)
  {
    angularDamping = damping;
  }
  
  /**
   * Updates the forces being applied to this rigidbody based on the fixed physics time step.
   */
  public synchronized void integrateForces()
  {
    // If this rigidbody is fixed in space then we don't need to integrate any forces.
    if (!kinematic)
    {
      return;
    }
    
    // Handle linear velocity
    linearVelocity.add(force.mult(inverseMass * PHYSICS_DELTA));
    if (gravity)
    {
      linearVelocity.add(0, GRAVITY_ACCELERATION * PHYSICS_DELTA, 0);
    }
    
    // Handle angular velocity
    PVector angularVelocityDelta = inverseInertiaWorld.transform(torque.mult(PHYSICS_DELTA));
    angularVelocity.add(angularVelocityDelta);
    
    // Reset the applied force/torque for the next update.
    force.set(0, 0, 0);
    torque.set(0, 0, 0);
  }
  
  /**
   * Applies velocity and angular velocity and recalculates any fields that are
   * specific to the state of our rigidbody.
   */
  public synchronized void integrate()
  {
    // Handle position
    position.add(PVector.mult(linearVelocity, PHYSICS_DELTA));
    
    // Handle rotation
    float angle = angularVelocity.mag();
    PVector axis;
    if (angle < 0.001f)
    {
      // We're using the taylor expansion of sync() here - since we can't divide through 0!
      float deltaCubed = PHYSICS_DELTA * PHYSICS_DELTA * PHYSICS_DELTA;
      axis = PVector.mult(
        angularVelocity,
        PHYSICS_DELTA / 2f - deltaCubed * 0.020833333333f * angle * angle);
    }
    else
    {
      axis = PVector.mult(angularVelocity, sin(angle * PHYSICS_DELTA / 2f) / angle);
    }
    
    Quaternion dorn = new Quaternion(axis.x, axis.y, axis.z, cos(angle * PHYSICS_DELTA / 2f));
    dorn.mult(orientation.toQuaternion());
    dorn.normalize();
    
    orientation.fromQuaternion(dorn);
    
    linearVelocity.mult(max(1f - linearDamping * PHYSICS_DELTA, 0));
    angularVelocity.mult(max(1f - angularDamping * PHYSICS_DELTA, 0));
    
    // Finally, update everything that has been affected by our calculations.
    update();
  }
  
  /**
   * Update our orientation and world space inertia.
   */
  public synchronized void update()
  {
    inverseOrientation = orientation.transpose();
    inverseInertiaWorld = inverseOrientation.mult(inverseInertia).mult(orientation);
  }
  
  /**
   * Draws all shapes related to this rigidbody at the local position and rotation.
   */
  public synchronized void draw()
  {
    pushMatrix();
    
    translate(position.x, position.y, position.z);
    
    PVector eulerAngles = orientation.toEulerAngles();
    rotateX(eulerAngles.x);
    rotateY(-eulerAngles.y);
    rotateZ(eulerAngles.z);
    
    for (PShape mesh : meshes)
    {
      shape(mesh);
    }
    
    popMatrix();
  }
  
  /**
   * This method is called whenever a hit is detected on this rigidbody. Does nothing by default.
   */
  public void onHit()
  {
    // NOP
  }
}

/**
 * A standard implementation of a 3x3 matrix since processing doesn't provide one.
 * The PMatrix is a 3x4 standard matrix.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class Matrix3x3
{
  /**
   * The top left of the matrix.
   */
  public float m00;
  
  /**
   * The top center of the matrix.
   */
  public float m01;
  
  /**
   * The top right of the matrix.
   */
  public float m02;
  
  /**
   * The center left of the matrix.
   */
  public float m10;
  
  /**
   * The center of the matrix.
   */
  public float m11;
  
  /**
   * The center right of the matrix.
   */
  public float m12;
  
  /**
   * The bottom left of the matrix.
   */
  public float m20;
  
  /**
   * The bottom center of the matrix.
   */
  public float m21;
  
  /**
   * The bottom right of the matrix.
   */
  public float m22;
  
  /**
   * Constructs an identity 3x3 matrix.
   */
  public Matrix3x3()
  {
    m00 = 1f;
    m11 = 1f;
    m22 = 1f;
  }
  
  /**
   * Sets all values of this matrix to 0.
   */
  public void clear()
  {
    m00 = m01 = m02 = m10 = m11 = m12 = m20 = m21 = m22 = 0;
  }
  
  /**
   * Calculates the determinant of the matrix.
   *
   * @returns The determinant.
   */
  public float determinant()
  {
    return m00 * m11 * m22
      + m01 * m12 * m20
      + m02 * m10 * m21
      - m20 * m11 * m02
      - m21 * m12 * m00
      - m22 * m10 * m01;
  }
  
  /**
   * Inverts this matrix and returns the result as a new instance.
   * Assumes that it is invertible.
   *
   * @returns The inverted matrix.
   */
  public Matrix3x3 inverse()
  {
    Matrix3x3 result = new Matrix3x3();
    float inverseDeterminant = 1f / determinant();
    
    result.m00 = (m11 * m22 - m12 * m21) * inverseDeterminant;
    result.m01 = (m02 * m21 - m22 * m01) * inverseDeterminant;
    result.m02 = (m01 * m12 - m11 * m02) * inverseDeterminant;
    result.m10 = (m12 * m20 - m10 * m22) * inverseDeterminant;
    result.m11 = (m00 * m22 - m02 * m20) * inverseDeterminant;
    result.m12 = (m02 * m10 - m00 * m12) * inverseDeterminant;
    result.m20 = (m10 * m21 - m11 * m20) * inverseDeterminant;
    result.m21 = (m01 * m20 - m00 * m21) * inverseDeterminant;
    result.m22 = (m00 * m11 - m01 * m10) * inverseDeterminant;
    
    return result;
  }
  
  /**
   * Transfroms the provided position vector according to this matrix.
   * Treats this matrix as a rotational matrix.
   *
   * @param position The position to transform.
   * @returns The transformed vector according to this rotation.
   */
  public PVector transform(PVector position)
  {
    return new PVector(
      position.x * m00 + position.y * m10 + position.z * m20,
      -(position.x * m01 + position.y * m11 + position.z * m21),
      position.x * m02 + position.y * m12 + position.z * m22);
  }
  
  /**
   * Adds the provided matrix to this instance.
   *
   * @param other The matrix to add to this one.
   */
  public void add(Matrix3x3 other)
  {
    m00 += other.m00;
    m01 += other.m01;
    m02 += other.m02;
    m10 += other.m10;
    m11 += other.m11;
    m12 += other.m12;
    m20 += other.m20;
    m21 += other.m21;
    m22 += other.m22;
  }
  
  /**
   * Subtracts the provided matrix from this instance.
   *
   * @param other The matrix to subtract from this one.
   */
  public void sub(Matrix3x3 other)
  {
    m00 -= other.m00;
    m01 -= other.m01;
    m02 -= other.m02;
    m10 -= other.m10;
    m11 -= other.m11;
    m12 -= other.m12;
    m20 -= other.m20;
    m21 -= other.m21;
    m22 -= other.m22;
  }
  
  /**
   * Matrix-multiplies this matrix with the provided one and returns the
   * result as a new instance.
   *
   * @param other The matrix to multiply this one with.
   * @returns A new matrix representing the result of the multiplication.
   */
  public Matrix3x3 mult(Matrix3x3 other)
  {
    Matrix3x3 target = new Matrix3x3();
    
    target.m00 = m00 * other.m00 + m01 * other.m10 + m02 * other.m20;
    target.m01 = m00 * other.m01 + m01 * other.m11 + m02 * other.m21;
    target.m02 = m00 * other.m02 + m01 * other.m12 + m02 * other.m22;
    target.m10 = m10 * other.m00 + m11 * other.m10 + m12 * other.m20;
    target.m11 = m10 * other.m01 + m11 * other.m11 + m12 * other.m21;
    target.m12 = m10 * other.m02 + m11 * other.m12 + m12 * other.m22;
    target.m20 = m20 * other.m00 + m21 * other.m10 + m22 * other.m20;
    target.m21 = m20 * other.m01 + m21 * other.m11 + m22 * other.m21;
    target.m22 = m20 * other.m02 + m21 * other.m12 + m22 * other.m22;
    
    return target;
  }
  
  /**
   * Multiplies this matrix with the provided scalar factor and
   * returns the result as a new instance.
   *
   * @param factor The scalar factor to multiply with.
   * @returns The multiplied matrix.
   */
  public Matrix3x3 mult(float factor)
  {
    Matrix3x3 target = new Matrix3x3();
    
    target.m00 = m00 * factor;
    target.m01 = m01 * factor;
    target.m02 = m02 * factor;
    target.m10 = m10 * factor;
    target.m11 = m11 * factor;
    target.m12 = m12 * factor;
    target.m20 = m20 * factor;
    target.m21 = m21 * factor;
    target.m22 = m22 * factor;
    
    return target;
  }
  
  /**
   * Transposes this matrix and returns the result in a new instance.
   *
   * @returns The transposed matrix.
   */
  public Matrix3x3 transpose()
  {
    Matrix3x3 target = new Matrix3x3();
    
    target.m00 = m00;
    target.m01 = m10;
    target.m02 = m20;
    target.m10 = m01;
    target.m11 = m11;
    target.m12 = m21;
    target.m20 = m02;
    target.m21 = m12;
    target.m22 = m22;
    
    return target;
  }
  
  /**
   * Constructs a rotational matrix based on the provided quaternial representation
   * of the rotation and stores the result in this instance.
   *
   * @param source The quaternion to construct this rotational matrix from.
   */
  public void fromQuaternion(Quaternion source)
  {
    m00 = 1f - (2f * (source.y * source.y + source.z * source.z));
    m01 = 2f * (source.x * source.y + source.z * source.w);
    m02 = 2f * (source.z * source.x - source.y * source.w);
    m10 = 2f * (source.x * source.y - source.z * source.w);
    m11 = 1f - (2f * (source.z * source.z + source.x * source.x));
    m12 = 2f * (source.y * source.z + source.x * source.w);
    m20 = 2f * (source.z * source.x + source.y * source.w);
    m21 = 2f * (source.y * source.z - source.x * source.w);
    m22 = 1f - (2f * (source.y * source.y + source.x * source.x));
  }
  
  /**
   * Constructs a quaternion based on this matrix, assuming it represents
   * a rotation.
   *
   * @returns A quaternial representation of this rotational matrix.
   */
  public Quaternion toQuaternion()
  {
    float num8 = m00 + m11 + m22;
    if (num8 > 0f)
    {
      float num = 2f * sqrt(num8 + 1f);
      return new Quaternion(
        (m12 - m21) / num,
        (m20 - m02) / num,
        (m01 - m10) / num,
        num / 4f);
    }
    else if (m00 >= m11 && m00 >= m22)
    {
      float num7 = 2f * sqrt(1f + m00 - m11 - m22);
      return new Quaternion(
        num7 / 4f,
        (m01 + m10) / num7,
        (m02 + m20) / num7,
        (m12 - m21) / num7);
    }
    else if (m11 > m22)
    {
      float num6 = 2f * sqrt(1f + m11 - m00 - m22);
      return new Quaternion(
        (m10 + m01) / num6,
        num6 / 4f,
        (m21 + m12) / num6,
        (m20 - m02) / num6);
    }
    else
    {
      float num5 = 2f * sqrt(1f + m22 - m00 - m11);
      return new Quaternion(
        (m20 + m02) / num5,
        (m21 + m12) / num5,
        num5 / 4f,
        (m01 - m10) / num5);
    }
  }
  
  /**
   * Converts this rotational matrix into euler angle representation.
   *
   * @returns The euler angles representation of this matrix.
   */
  public PVector toEulerAngles()
  {
    return new PVector(
      atan2(m21, m22),
      atan2(-m20, sqrt(m21 * m21 + m22 * m22)),
      atan2(m10, m00));
  }
  
  @Override
  public String toString()
  {
    StringBuilder builder = new StringBuilder();
    builder.append(m00).append(' ').append(m01).append(' ').append(m02).append(' ').append('\n');
    builder.append(m10).append(' ').append(m11).append(' ').append(m12).append(' ').append('\n');
    builder.append(m20).append(' ').append(m21).append(' ').append(m22).append(' ').append('\n');
    return builder.toString();
  }
}

/**
 * A standard implementation for a quaternion, used in 3D rotations.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class Quaternion
{
  /**
   * The x component of the quaternion.
   */
  private float x;
  
  /**
   * The y component of the quaternion.
   */
  private float y;
  
  /**
   * The z component of the quaternion.
   */
  private float z;
  
  /**
   * The w component of the quaternion.
   */
  private float w;
  
  /**
   * Constructs a new identity quaternion.
   */
  public Quaternion()
  {
    this(0, 0, 0, 1);
  }
  
  /**
   * Constructs a new quaternion given the four components.
   *
   * @param x The x component.
   * @param y The y component.
   * @param z The z component.
   * @param w The w component.
   */
  public Quaternion(float x, float y, float z, float w)
  {
    this.x = x;
    this.y = y;
    this.z = z;
    this.w = w;
  }
  
  /**
   * Multiplies this quaternion with the provided one and returns the result as a new
   * instance. This is a 3d rotation.
   *
   * @param other The quaternion to multiply by.
   * @returns A new quaternion storing the result.
   */
  public Quaternion mult(Quaternion other)
  {
    return new Quaternion(
      x * other.w + other.x * w + y * other.z - z * other.y,
      y * other.w + other.y * w + z * other.x - x * other.z,
      z * other.w + other.z * w + x * other.y - y * other.x,
      w * other.w - (x * other.x + y * other.y + z * other.z));
  }
  
  /**
   * Normalizes this quaternion so the square of all components adds up to 1.
   */
  public void normalize()
  {
    float inverseLength = 1f / sqrt(x * x + y * y + z * z + w * w);
    x *= inverseLength;
    y *= inverseLength;
    z *= inverseLength;
    w *= inverseLength;
  }
}
