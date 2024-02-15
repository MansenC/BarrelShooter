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
 */
public static class PhysicsManager
{ 
  /**
   * Whether or not the physics are updated or not.
   */
  private static volatile boolean running = true;
  
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
    RIGIDBODIES.add(rigidbody);
  }
  
  /**
   * Removes a given rigidbody from the physics engine.
   */
  public static void removeRigidbody(Rigidbody rigidbody)
  {
    RIGIDBODIES.remove(rigidbody);
  }
  
  public static volatile boolean physicsFrame = true;
  
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
      
      do
      {
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
      while (!physicsFrame);
      
      physicsFrame = true;
    }
  }
  
  private static void updateRigidbodies()
  {
    // First step: Collision. TODO Collision
    
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

public class Rigidbody
{
  public static final float FORCE_SCALE = 100f;
  
  private static final float GRAVITY_ACCELERATION = 9.81f;
  
  private final PShape mesh;
  protected final PVector position;
  private final Matrix3x3 orientation = new Matrix3x3();
  private final Matrix3x3 inertia = new Matrix3x3(); // TODO for now this is defined as the identity. Will come from shape.
  private final Matrix3x3 inverseInertia = new Matrix3x3();
  private Matrix3x3 inverseOrientation = new Matrix3x3();
  private Matrix3x3 inverseInertiaWorld = new Matrix3x3(); // inverse inertia tensor in world space
  
  private final PVector force = new PVector();
  private final PVector torque = new PVector();
  private final PVector linearVelocity = new PVector();
  private final PVector angularVelocity = new PVector();
  
  private boolean kinematic = true;
  private boolean gravity = true;
  protected float inverseMass = 1f;
  private float linearDamping = 0f;
  private float angularDamping = 0f;
  
  public Rigidbody(PShape mesh, PVector position)
  {
    this.mesh = mesh;
    this.position = position;
  }
  
  public PVector getPosition()
  {
    return position;
  }
  
  public void setMass(float mass)
  {
    inverseMass = 1f / mass;
  }
  
  public synchronized void addForce(PVector force)
  {
    this.force.add(force);
  }
  
  public synchronized void addTorque(PVector torque)
  {
    this.torque.add(torque);
  }
  
  public synchronized void addForceAtPoint(PVector force, PVector point)
  {
    this.force.add(force);
    
    point.sub(position).mult(1f / FORCE_SCALE);
    torque.add(point.cross(force));
  }
  
  public PVector transformLocalPosition(PVector localPosition)
  {
    PVector rotatedPosition = orientation.transform(localPosition);
    return rotatedPosition.add(position);
  }
  
  public void setLinearDamping(float damping)
  {
    linearDamping = damping;
  }
  
  public void setAngularDamping(float damping)
  {
    angularDamping = damping;
  }
  
  public synchronized void integrateForces()
  {
    // If this rigidbody is fixed in space then we don't need to integrate any forces.
    if (!kinematic)
    {
      return;
    }
    
    // Handle linear velocity
    linearVelocity.add(force.mult(inverseMass * PHYSICS_DELTA * FORCE_SCALE));
    if (gravity)
    {
      linearVelocity.add(0, GRAVITY_ACCELERATION * PHYSICS_DELTA * FORCE_SCALE, 0);
    }
    
    // Handle angular velocity
    PVector angularVelocityDelta = inverseInertiaWorld.transform(torque.mult(PHYSICS_DELTA));
    angularVelocity.add(angularVelocityDelta);
    
    // Reset the applied force/torque for the next update.
    force.set(0, 0, 0);
    torque.set(0, 0, 0);
  }
  
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
  
  public synchronized void update()
  {
    inverseOrientation = orientation.transpose();
    // Update bounding box?
    
    inverseInertiaWorld = inverseOrientation.mult(inverseInertia).mult(orientation);
  }
  
  public synchronized void draw()
  {
    pushMatrix();
    
    translate(position.x, position.y, position.z);
    
    PVector eulerAngles = orientation.toEulerAngles();
    rotateX(eulerAngles.x);
    rotateY(-eulerAngles.y);
    rotateZ(eulerAngles.z);
    
    shape(mesh);
    
    popMatrix();
  }
}

public class Matrix3x3
{
  public float m00;
  public float m01;
  public float m02;
  public float m10;
  public float m11;
  public float m12;
  public float m20;
  public float m21;
  public float m22;
  
  public Matrix3x3()
  {
    m00 = 1f;
    m11 = 1f;
    m22 = 1f;
  }
  
  public PVector transform(PVector position)
  {
    return new PVector(
      position.x * m00 + position.y * m10 + position.z * m20,
      -(position.x * m01 + position.y * m11 + position.z * m21),
      position.x * m02 + position.y * m12 + position.z * m22);
  }
  
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
  
  // Quaternion from rotation matrix
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

public class Quaternion
{
  private float x;
  private float y;
  private float z;
  private float w;
  
  public Quaternion()
  {
    this(0, 0, 0, 1);
  }
  
  public Quaternion(float x, float y, float z, float w)
  {
    this.x = x;
    this.y = y;
    this.z = z;
    this.w = w;
  }
  
  public Quaternion mult(Quaternion other)
  {
    return new Quaternion(
      x * other.w + other.x * w + y * other.z - z * other.y,
      y * other.w + other.y * w + z * other.x - x * other.z,
      z * other.w + other.z * w + x * other.y - y * other.x,
      w * other.w - (x * other.x + y * other.y + z * other.z));
  }
  
  public void normalize()
  {
    float inverseLength = 1f / sqrt(x * x + y * y + z * z + w * w);
    x *= inverseLength;
    y *= inverseLength;
    z *= inverseLength;
    w *= inverseLength;
  }
}
