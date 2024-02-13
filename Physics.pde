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
      for (Rigidbody rigidbody : RIGIDBODIES)
      {
        rigidbody.update();
      }
      
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
}

/**
 * Rigidbody docs TODO. Same for Matrix3x4
 */
public class Rigidbody
{
  public static final float FORCE_SCALE = 100f;
  
  private final PShape mesh;
  private final PVector position;
  private Quaternion rotation = new Quaternion();
  private final PVector velocity = new PVector();
  private final PVector constantAcceleration = new PVector();
  private final PVector lastFrameAcceleration = new PVector();
  
  private float inverseMass = 1;
  private float linearDamping = 1;
  private float angularDamping = 1;
  
  private final PVector angularVelocity = new PVector();
  private Matrix3x4 transformMatrix = new Matrix3x4();
  private Matrix3x3 inverseInertiaTensor = new Matrix3x3();
  private Matrix3x3 inverseInertiaTensorWorld = new Matrix3x3();
  
  private final PVector currentForces = new PVector();
  private final PVector currentTorque = new PVector();
  
  private boolean kinematic = true;
  
  public Rigidbody(PShape mesh, PVector position)
  {
    this.mesh = mesh;
    this.position = position;
    
    PhysicsManager.registerRigidbody(this);
  }
  
  /**
   * Removes this rigidbody from our physics loop. Without calling this,
   * the rigidbody will get updated in the background.
   */
  public void remove()
  {
    PhysicsManager.removeRigidbody(this);
  }
  
  public void setUseGravity()
  {
      constantAcceleration.add(0, 9.81f, 0);
  }
  
  public void addForce(PVector force)
  {
    currentForces.add(force);
  }
  
  public void addTorque(PVector torque)
  {
    currentTorque.add(torque);
  }
  
  public void addForceAtPoint(PVector force, PVector point)
  {
    PVector targetPoint = point.copy();
    targetPoint.sub(position);
    
    currentForces.add(force);
    currentTorque.add(targetPoint.cross(force));
  }
  
  public PVector getPosition()
  {
    return position;
  }
  
  public void setKinematic(boolean kinematic)
  {
    this.kinematic = kinematic;
  }
  
  /**
   * Updates the physics of this given rigidbody. Synchronized because it may overlap
   * with our calls to {@link #draw()}.
   */
  public synchronized void update()
  {
    if (!kinematic)
    {
      return;
    }
    
    applyKinematics();
  }
  
  /**
   * Actually draws the rigidbody on screen. This should be called from processing's core loop.
   * Synchronized because it may overlap with our calls to {@link #update()}.
   */
  public synchronized void draw()
  {
    // Now we can render our mesh.
    pushMatrix();
    
    translate(position.x, position.y, position.z);
    
    // We convert our quaternion into yaw/pitch/roll, i.e. euler angles
    float yaw = atan2(2f * (rotation.y * rotation.z + rotation.w * rotation.x), rotation.w * rotation.w - rotation.x * rotation.x - rotation.y * rotation.y + rotation.z * rotation.z);
    float pitch = asin(-2f * (rotation.x * rotation.z - rotation.w * rotation.y));
    float roll = atan2(2f * (rotation.x * rotation.y + rotation.w * rotation.z), rotation.w * rotation.w + rotation.x * rotation.x - rotation.y * rotation.y - rotation.z * rotation.z);
    
    rotateY(yaw);
    rotateZ(pitch);
    rotateX(roll);
    
    shape(mesh);
    
    popMatrix();
  }
  
  private void applyKinematics()
  {
    // Set the last frame acceleration to the current value of acceleration.
    // Since we know that F=m*a and we apply directional forces to the rigidbodies,
    // our acceleration is defined as F/m which we apply here after our constant
    // acceleration.
    lastFrameAcceleration.set(constantAcceleration);
    lastFrameAcceleration.add(currentForces.mult(inverseMass));
    
    // Now calculate the angular acceleration, apply the acceleration to this frame
    // and then apply the angular acceleration
    PVector angularAcceleration = inverseInertiaTensorWorld.transform(currentTorque);
    velocity.add(PVector.mult(lastFrameAcceleration, PHYSICS_DELTA * FORCE_SCALE));
    
    angularVelocity.add(angularAcceleration.mult(PHYSICS_DELTA * FORCE_SCALE));
    
    // Calculate the dampened velocities. This is calculating drag.
    velocity.mult(pow(linearDamping, PHYSICS_DELTA * FORCE_SCALE));
    angularVelocity.mult(pow(angularDamping, PHYSICS_DELTA * FORCE_SCALE));
    
    // We then increase or position and rotation according to our calculated values.
    position.add(PVector.mult(velocity, PHYSICS_DELTA));
    rotation.addScaledVector(angularVelocity, PHYSICS_DELTA);
    
    // We finally normalize the rotation so it is a valid rotational quaternion again.
    rotation.normalize();
    
    // Then we calculate the new transformations for our position/rotation and inertia.
    transformMatrix.setOrientationAndPosition(rotation, position);
    transformInertiaTensor(inverseInertiaTensorWorld, inverseInertiaTensor, transformMatrix);
    
    // And lastly we clear the accumulated forces and torque.
    currentForces.set(0, 0, 0);
    currentTorque.set(0, 0, 0);
  }
  
  // I usually really dislike abbreviated names, but here it really is neccessary.
  private void transformInertiaTensor(
    Matrix3x3 iitWorld,
    Matrix3x3 iitBody,
    Matrix3x4 rotMat)
  {
    float t4 = rotMat.m00 * iitBody.m00 + rotMat.m01 * iitBody.m10 + rotMat.m02 * iitBody.m20;
    float t9 = rotMat.m00 * iitBody.m01 + rotMat.m01 * iitBody.m11 + rotMat.m02 * iitBody.m21;
    float t14 = rotMat.m00 * iitBody.m02 + rotMat.m01 * iitBody.m12 + rotMat.m02 * iitBody.m22;
    float t28 = rotMat.m10 * iitBody.m00 + rotMat.m11 * iitBody.m10 + rotMat.m12 * iitBody.m20;
    float t33 = rotMat.m10 * iitBody.m01 + rotMat.m11 * iitBody.m11 + rotMat.m12 * iitBody.m21;
    float t38 = rotMat.m10 * iitBody.m02 + rotMat.m11 * iitBody.m12 + rotMat.m12 * iitBody.m22;
    float t52 = rotMat.m20 * iitBody.m00 + rotMat.m21 * iitBody.m10 + rotMat.m22 * iitBody.m20;
    float t57 = rotMat.m20 * iitBody.m01 + rotMat.m21 * iitBody.m11 + rotMat.m22 * iitBody.m21;
    float t62 = rotMat.m20 * iitBody.m02 + rotMat.m21 * iitBody.m12 + rotMat.m22 * iitBody.m22;
    
    iitWorld.m00 = t4 * rotMat.m00 + t9 * rotMat.m01 + t14 * rotMat.m02;
    iitWorld.m01 = t4 * rotMat.m10 + t9 * rotMat.m11 + t14 * rotMat.m12;
    iitWorld.m02 = t4 * rotMat.m20 + t9 * rotMat.m21 + t14 * rotMat.m22;
    iitWorld.m10 = t28 * rotMat.m00 + t33 * rotMat.m01 + t38 * rotMat.m02;
    iitWorld.m11 = t28 * rotMat.m10 + t33 * rotMat.m11 + t38 * rotMat.m12;
    iitWorld.m12 = t28 * rotMat.m20 + t33 * rotMat.m21 + t38 * rotMat.m22;
    iitWorld.m20 = t52 * rotMat.m00 + t57 * rotMat.m01 + t62 * rotMat.m02;
    iitWorld.m21 = t52 * rotMat.m10 + t57 * rotMat.m11 + t62 * rotMat.m12;
    iitWorld.m22 = t52 * rotMat.m20 + t57 * rotMat.m21 + t62 * rotMat.m22;
  }
}

/**
 * This is a really simple and small implementation of quaternions. They can do a lot more than this
 * but this is all I need. They're just for 3d rotations in our rigidbody.
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
   * Constructs an identity quaternion that applies no rotation at all.
   */
  public Quaternion()
  {
    this(0, 0, 0, 1);
  }
  
  /**
   * Constructs a quaternion from the given individual components.
   */
  public Quaternion(float x, float y, float z, float w)
  {
    this.x = x;
    this.y = y;
    this.z = z;
    this.w = w;
  }
  
  /**
   * Normalizes the quaternion so that x, y, z and w all individually squared and added up
   * equals to one.
   */
  public void normalize()
  {
    float determinant = x * x + y * y + z * z + w * w;
    if (determinant == 0)
    {
      w = 1f;
      return;
    }
    
    float inverseDeterminant = 1 / sqrt(determinant);
    x *= inverseDeterminant;
    y *= inverseDeterminant;
    z *= inverseDeterminant;
    w *= inverseDeterminant;
  }
  
  /**
   * Rotates this quaternion by the amount provided by the other quaternion. This is what quaternion
   * multiplication does.
   *
   * @param other The other quaternion.
   */
  public void mult(Quaternion other)
  {
    float newX = w * other.x + x * other.w + y * other.z - z * other.y;
    float newY = w * other.y + y * other.w + z * other.x - x * other.z;
    float newZ = w * other.z + z * other.w + x * other.y - y * other.x;
    float newW = w * other.w - x * other.x - y * other.y - z * other.z;
    
    x = newX;
    y = newY;
    z = newZ;
    w = newW;
  }
  
  /**
   * This one is unorthodox but it works great. This adds a "scaled vector" to our quaternion here.
   * Essentially one can think of this as adding a vector perpendicular to a given circle. It's a weird
   * concept but it works really well here.
   *
   * @param vector The vector to add.
   * @param scale The scale of the provided vector.
   */
  public void addScaledVector(PVector vector, float scale)
  {
    Quaternion target = new Quaternion(vector.x * scale, vector.y * scale, vector.z * scale, 0);
    target.mult(this);
    
    x += target.x / 2f;
    y += target.y / 2f;
    z += target.z / 2f;
    w += target.w / 2f;
  }
}

/**
 * Since processing only provides us with a 3x2 and 4x4 matrix, we have to implement 3x3 ourselves.
 * This is a standard implementation of a 3x3 matrix using floats. We do not implement the PMatrix
 * interface since it requires a lot of useless functionality.
 * TODO do I need to flip?
 * 
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class Matrix3x3
{
  public float m00,
    m01,
    m02,
    m10,
    m11,
    m12,
    m20,
    m21,
    m22;

  /**
   * Constructor for Matrix3f. Matrix is initialised to the identity.
   */
  public Matrix3x3()
  {
    setIdentity();
  }

  /**
   * Copies a source matrix into this one.
   
   * @param src The source matrix.
   * @return This matrix.
   */
  public Matrix3x3 load(Matrix3x3 src)
  {
    m00 = src.m00;
    m10 = src.m10;
    m20 = src.m20;
    m01 = src.m01;
    m11 = src.m11;
    m21 = src.m21;
    m02 = src.m02;
    m12 = src.m12;
    m22 = src.m22;

    return this;
  }

  /**
   * Adds another matrix to this one. In a matrix addition of A+B, this matrix represents A.
   
   * @param right The right source matrix.
   */
  public void add(Matrix3x3 right)
  {
    m00 += right.m00;
    m01 += right.m01;
    m02 += right.m02;
    m10 += right.m10;
    m11 += right.m11;
    m12 += right.m12;
    m20 += right.m20;
    m21 += right.m21;
    m22 += right.m22;
  }

  /**
   * Subtracts another matrix from this one. In a matrix addition of A-B, this matrix represents A.
   
   * @param right The right source matrix.
   */
  public void sub(Matrix3x3 right)
  {
    m00 -= right.m00;
    m01 -= right.m01;
    m02 -= right.m02;
    m10 -= right.m10;
    m11 -= right.m11;
    m12 -= right.m12;
    m20 -= right.m20;
    m21 -= right.m21;
    m22 -= right.m22;
  }

  /**
   * Multipies this matrix with another one. In a matrix multiplication A*B, this matrix represents A.
   
   * @param right The right source matrix.
   */
  public void mult(Matrix3x3 right)
  {
    float m00 = this.m00 * right.m00 + this.m10 * right.m01 + this.m20 * right.m02;
    float m01 = this.m01 * right.m00 + this.m11 * right.m01 + this.m21 * right.m02;
    float m02 = this.m02 * right.m00 + this.m12 * right.m01 + this.m22 * right.m02;
    float m10 = this.m00 * right.m10 + this.m10 * right.m11 + this.m20 * right.m12;
    float m11 = this.m01 * right.m10 + this.m11 * right.m11 + this.m21 * right.m12;
    float m12 = this.m02 * right.m10 + this.m12 * right.m11 + this.m22 * right.m12;
    float m20 = this.m00 * right.m20 + this.m10 * right.m21 + this.m20 * right.m22;
    float m21 = this.m01 * right.m20 + this.m11 * right.m21 + this.m21 * right.m22;
    float m22 = this.m02 * right.m20 + this.m12 * right.m21 + this.m22 * right.m22;

    this.m00 = m00;
    this.m01 = m01;
    this.m02 = m02;
    this.m10 = m10;
    this.m11 = m11;
    this.m12 = m12;
    this.m20 = m20;
    this.m21 = m21;
    this.m22 = m22;
  }
  
  /**
   * Multiplies the current matrix by the provided scalar factor.
   *
   * @param scalar The scalar factor to multiply by.
   */
  public void mult(float scalar)
  {
    m00 *= scalar;
    m01 *= scalar;
    m02 *= scalar;
    m10 *= scalar;
    m11 *= scalar;
    m12 *= scalar;
    m20 *= scalar;
    m21 *= scalar;
    m22 *= scalar;
  }

  /**
   * Transforms a vector by this matrix and returns the result. In a multiplication of
   * A*B, where B is the vector, A is this matrix.
   *
   * @param right The right vector.
   * @return The transformed vector.
   */
  public PVector transform(PVector right)
  {
    float x = m00 * right.x + m10 * right.y + m20 * right.z;
    float y = m01 * right.x + m11 * right.y + m21 * right.z;
    float z = m02 * right.x + m12 * right.y + m22 * right.z;

    return new PVector(x, y, z);
  }

  /**
   * Transposes this matrix.
   */
  public void transpose()
  {
    float m00 = this.m00;
    float m01 = this.m10;
    float m02 = this.m20;
    float m10 = this.m01;
    float m11 = this.m11;
    float m12 = this.m21;
    float m20 = this.m02;
    float m21 = this.m12;
    float m22 = this.m22;

    this.m00 = m00;
    this.m01 = m01;
    this.m02 = m02;
    this.m10 = m10;
    this.m11 = m11;
    this.m12 = m12;
    this.m20 = m20;
    this.m21 = m21;
    this.m22 = m22;
  }

  /**
   * Calculates the determinant for this matrix.
   *
   * @return the determinant of the matrix
   */
  public float determinant()
  {
    return m00 * (m11 * m22 - m12 * m21)
      + m01 * (m12 * m20 - m10 * m22)
      + m02 * (m10 * m21 - m11 * m20);
  }

  /**
   * Inverts this matrix.
   */
  public void invert()
  {
    float determinant = determinant();
    if (determinant == 0)
    {
      throw new IllegalStateException("Cannot invert a 3x3 matrix with a determinant of 0!");
    }
    
    /*
     * Do it the ordinary way:
     * inv(A) = 1/det(A) * adj(T), where adj(T) = transpose(Conjugate Matrix)
     */
    float inverseDeterminant = 1f / determinant;
    
    // get the conjugate matrix
    float t00 = m11 * m22 - m12* m21;
    float t01 = -m10 * m22 + m12 * m20;
    float t02 = m10 * m21 - m11 * m20;
    float t10 = -m01 * m22 + m02 * m21;
    float t11 = m00 * m22 - m02 * m20;
    float t12 = -m00 * m21 + m01 * m20;
    float t20 = m01 * m12 - m02 * m11;
    float t21 = -m00 * m12 + m02 * m10;
    float t22 = m00 * m11 - m01 * m10;
    
    m00 = t00 * inverseDeterminant;
    m11 = t11 * inverseDeterminant;
    m22 = t22 * inverseDeterminant;
    m01 = t10 * inverseDeterminant;
    m10 = t01 * inverseDeterminant;
    m20 = t02 * inverseDeterminant;
    m02 = t20 * inverseDeterminant;
    m12 = t21 * inverseDeterminant;
    m21 = t12 * inverseDeterminant;
  }

  /**
   * Negates this matrix.
   */
  public void negate()
  {
    m00 = -m00;
    m01 = -m02;
    m02 = -m01;
    m10 = -m10;
    m11 = -m12;
    m12 = -m11;
    m20 = -m20;
    m21 = -m22;
    m22 = -m21;
  }

  /**
   * Sets this matrix to be the identity matrix.
   */
  public void setIdentity() {
    m00 = 1.0f;
    m01 = 0.0f;
    m02 = 0.0f;
    m10 = 0.0f;
    m11 = 1.0f;
    m12 = 0.0f;
    m20 = 0.0f;
    m21 = 0.0f;
    m22 = 1.0f;
  }

  /**
   * Sets this matrix to 0.
   */
  public void setZero() {
    m00 = 0.0f;
    m01 = 0.0f;
    m02 = 0.0f;
    m10 = 0.0f;
    m11 = 0.0f;
    m12 = 0.0f;
    m20 = 0.0f;
    m21 = 0.0f;
    m22 = 0.0f;
  }

  @Override
  public String toString()
  {
    StringBuilder builder = new StringBuilder();
    builder.append(m00).append(' ').append(m10).append(' ').append(m20).append(' ').append('\n');
    builder.append(m01).append(' ').append(m11).append(' ').append(m21).append(' ').append('\n');
    builder.append(m02).append(' ').append(m12).append(' ').append(m22).append(' ').append('\n');
    return builder.toString();
  }
}

/**
 * We also unfortunately need a Matrix3x4, which means 3 rows 4 columns. This also is used in our rigidbody
 * but in this case for the transform.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class Matrix3x4
{
  public float m00; // 0
  public float m01; // 1
  public float m02; // 2
  public float m03; // 3
  public float m10; // 4
  public float m11; // 5
  public float m12; // 6
  public float m13; // 7
  public float m20; // 8
  public float m21; // 9
  public float m22; // 10
  public float m23; // 11
  
  public Matrix3x4()
  {
    setIdentity();
  }
  
  public PVector transform(PVector right)
  {
    float x = right.x * m00 + right.y * m01 + right.z * m02 + m03;
    float y = right.x * m10 + right.y * m11 + right.z * m12 + m13;
    float z = right.x * m20 + right.y * m21 + right.z * m22 + m23;
    
    return new PVector(x, y, z);
  }
  
  public PVector transformInverse(PVector right)
  {
    PVector temp = right.copy();
    temp.sub(m03, m13, m23);
    return new PVector(
      temp.x * m00 + temp.y * m10 + temp.z * m20,
      temp.x * m01 + temp.y * m11 + temp.z * m21,
      temp.x * m02 + temp.y * m12 + temp.z * m22);
  }
  
  public PVector transformDirection(PVector right)
  {
    float x = right.x * m00 + right.y * m01 + right.z * m02;
    float y = right.x * m10 + right.y * m11 + right.z * m12;
    float z = right.x * m20 + right.y * m21 + right.z * m22;
    
    return new PVector(x, y, z);
  }
  
  public PVector transformInverseDirection(PVector right)
  {
    float x = right.x * m00 + right.y * m10 + right.z * m20;
    float y = right.x * m01 + right.y * m11 + right.z * m21;
    float z = right.x * m02 + right.y * m12 + right.z * m22;
    
    return new PVector(x, y, z);
  }
  
  public void mult(Matrix3x4 right)
  {
    float m00 = this.m00 * right.m00 + this.m01 * right.m10 + this.m02 * right.m20;
    float m01 = this.m00 * right.m01 + this.m01 * right.m11 + this.m02 * right.m21;
    float m02 = this.m00 * right.m02 + this.m01 * right.m12 + this.m02 * right.m22;
    float m03 = this.m00 * right.m03 + this.m01 * right.m13 + this.m02 * right.m23 + this.m03;
    float m10 = this.m10 * right.m00 + this.m11 * right.m10 + this.m12 * right.m20;
    float m11 = this.m10 * right.m01 + this.m11 * right.m11 + this.m12 * right.m21;
    float m12 = this.m10 * right.m02 + this.m11 * right.m12 + this.m12 * right.m22;
    float m13 = this.m10 * right.m03 + this.m11 * right.m13 + this.m12 * right.m23 + this.m13;
    float m20 = this.m20 * right.m00 + this.m21 * right.m10 + this.m22 * right.m20;
    float m21 = this.m20 * right.m01 + this.m21 * right.m11 + this.m22 * right.m21;
    float m22 = this.m20 * right.m02 + this.m21 * right.m12 + this.m22 * right.m22;
    float m23 = this.m20 * right.m03 + this.m21 * right.m13 + this.m22 * right.m23 + this.m23;
    
    this.m00 = m00;
    this.m01 = m01;
    this.m02 = m02;
    this.m03 = m03;
    this.m10 = m10;
    this.m11 = m11;
    this.m12 = m12;
    this.m13 = m13;
    this.m20 = m20;
    this.m21 = m21;
    this.m22 = m22;
    this.m23 = m23;
  }
  
  public float determinant()
  {
    return m00 * m11 * m22
      - m00 * m12 * m21
      - m01 * m10 * m22
      + m01 * m12 * m20
      + m02 * m10 * m21
      - m02 * m11 * m20;
  }
  
  public void invert()
  {
    float determinant = determinant();
    if (determinant == 0)
    {
      throw new IllegalStateException("Cannot invert a 3x3 matrix with a determinant of 0!");
    }
    
    float inverseDeterminant = 1 / determinant;
    float t00 = m11 * m22 - m12 * m21;
    float t01 = m02 * m21 - m01 * m22;
    float t02 = m01 * m12 - m02 * m11;
    float t03 = m03 * m12 * m21
              + m02 * m11 * m23
              + m01 * m13 * m22
              - m01 * m12 * m23
              - m02 * m13 * m21
              - m03 * m11 * m22;
    float t10 = m12 * m20 - m10 * m22;
    float t11 = m00 * m22 - m02 * m20;
    float t12 = m02 * m10 - m00 * m12;
    float t13 = m03 * m10 * m22
              + m02 * m13 * m20
              + m00 * m12 * m23
              - m03 * m12 * m20
              - m02 * m10 * m23
              - m00 * m13 * m22;
    float t20 = m10 * m21 - m11 * m20;
    float t21 = m01 * m20 - m00 * m21;
    float t22 = m00 * m11 - m01 * m10;
    float t23 = m03 * m11 * m20
              + m01 * m10 * m23
              + m00 * m13 * m21
              - m03 * m10 * m21
              - m00 * m11 * m23
              - m01 * m13 * m20;
    
    m00 = t00 * inverseDeterminant;
    m01 = t01 * inverseDeterminant;
    m02 = t02 * inverseDeterminant;
    m03 = t03 * inverseDeterminant;
    m10 = t10 * inverseDeterminant;
    m11 = t11 * inverseDeterminant;
    m12 = t12 * inverseDeterminant;
    m13 = t13 * inverseDeterminant;
    m20 = t20 * inverseDeterminant;
    m21 = t21 * inverseDeterminant;
    m22 = t22 * inverseDeterminant;
    m23 = t23 * inverseDeterminant;
  }
  
  public void setOrientationAndPosition(Quaternion orientation, PVector position)
  {
    m00 = 1 - (2 * orientation.y * orientation.y + 2 * orientation.z * orientation.z);
    m01 = 2 * orientation.x * orientation.y + 2 * orientation.z * orientation.w;
    m02 = 2 * orientation.x * orientation.z - 2 * orientation.y * orientation.w;
    m03 = position.x;
    
    m10 = 2 * orientation.x * orientation.y - 2 * orientation.z * orientation.w;
    m11 = 1 - (2 * orientation.x * orientation.x + 2 * orientation.z * orientation.z);
    m12 = 2 * orientation.y * orientation.z + 2 * orientation.x * orientation.w;
    m13 = position.y;
    
    m20 = 2 * orientation.x * orientation.z + 2 * orientation.y * orientation.w;
    m21 = 2 * orientation.y * orientation.z - 2 * orientation.x * orientation.w;
    m22 = 1 - (2 * orientation.x * orientation.x + 2 * orientation.y * orientation.y);
    m23 = position.z;
  }
  
  public void setIdentity()
  {
    m00 = 1;
    m01 = 0;
    m02 = 0;
    m03 = 0;
    m10 = 0;
    m11 = 1;
    m12 = 0;
    m13 = 0;
    m20 = 0;
    m21 = 0;
    m22 = 1;
    m23 = 0;
  }

  @Override
  public String toString()
  {
    StringBuilder builder = new StringBuilder();
    builder.append(m00).append(' ').append(m01).append(' ').append(m02).append(' ').append(m03).append(' ').append('\n');
    builder.append(m10).append(' ').append(m11).append(' ').append(m12).append(' ').append(m13).append(' ').append('\n');
    builder.append(m20).append(' ').append(m21).append(' ').append(m22).append(' ').append(m23).append(' ').append('\n');
    return builder.toString();
  }
}
