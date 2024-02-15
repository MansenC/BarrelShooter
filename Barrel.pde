import java.util.ArrayList;
import java.util.List;
import java.util.Random;

PShape barrelShape;

/**
 * Handles the spawning and updating of all barrels in the world.
 */
public class BarrelManager
{
  /**
   * The starting position of barrel spawning. This is the smaller circle of the spawning area.
   */
  private static final float BARREL_SPAWN_X_START = 4_000;
  
  /**
   * The ending position of barrel spawning. This is the larger circle of the spawning area.
   */
  private static final float BARREL_SPAWN_X_END = 9_000;
  
  /**
   * The maximum (and inverted minimum) angle of difference at which barrels can spawn.
   */
  private static final float BARREL_SPAWN_Y_ANGLE = 40f;
  
  /**
   * The minimum distance between two barrels (X/Z).
   */
  private static final float BARREL_MIN_DISTANCE = 400f;
  
  /**
   * The cannon origin describes the center point of the circles that describe the boundary
   * of where barrels can spawn in the water.
   */
  private final PVector cannonOrigin;
  
  /**
   * The list of all barrels that currently are being displayed.
   */
  private final List<Barrel> barrels = new ArrayList<>();
  
  public BarrelManager(PVector origin)
  {
    cannonOrigin = origin;
  }
  
  public void spawnBarrels(int amount)
  {
    // We will spawn barrels randomly around the ocean.
    Random random = new Random();
    while (barrels.size() < amount)
    {
      // We calculate a random angle and distance at which the barrel will be placed.
      float targetYAngle = random.nextFloat(-BARREL_SPAWN_Y_ANGLE, BARREL_SPAWN_Y_ANGLE);
      float targetDistance = random.nextFloat(BARREL_SPAWN_X_START, BARREL_SPAWN_X_END);
      
      PVector targetPosition = new PVector(
        cos(radians(targetYAngle)) * targetDistance,
        0, // For now a fixed Y position, later we'll sample the current wave height
        sin(radians(targetYAngle)) * targetDistance);
      targetPosition.add(cannonOrigin);
      
      // BARREL_MIN_DISTANCE
      // We then check if there's a barrel already close by. If so, we skip this position and try again.
      boolean failedDistanceCheck = false;
      for (Barrel existingBarrel : barrels)
      {
        PVector existingPosition = existingBarrel.getRigidbody().getPosition();
        float distanceX = targetPosition.x - existingPosition.x;
        float distanceZ = targetPosition.z - existingPosition.z;
        
        // We only care about X|Z coordinates, Y doesn't matter here.
        failedDistanceCheck = distanceX * distanceX + distanceZ * distanceZ < BARREL_MIN_DISTANCE * BARREL_MIN_DISTANCE;
        if (failedDistanceCheck)
        {
          break;
        }
      }
      
      if (failedDistanceCheck)
      {
        // We have failed the distance check. Let's try again.
        continue;
      }
      
      // If not then we calculate the current ocean height and adjust the barrel's starting Y position accordingly.
      targetPosition.y = sampleOceanY(targetPosition.x, targetPosition.z);
      barrels.add(new Barrel(targetPosition));
    }
  }
  
  public void update()
  {
    for (Barrel barrel : barrels)
    {
      barrel.draw();
    }
  }
}

/**
 * The barrel class manages the buoyancy simulation part. Barrels can spawn randomly on the ocean
 * and will get affected by the waves, and pushed around. Like everything on a computer, Physics
 * cannot be calculated exactly with such a complex subject, this is why it's an approximation.
 * The calculations on this approximation, however, are exact.
 *
 * Essentially we wrap our barrel in a cylinder and then voxilize this cylinder. We then calculate
 * if said voxel is beneath the water surface based on its center position and then apply force
 * accordingly to the barrel. This will then move and rotate the barrel accordingly.
 */
public class Barrel
{
  private final BarrelRigidbody rigidbody;
  
  public Barrel(PVector position)
  {
    rigidbody = new BarrelRigidbody(position);
  }
  
  public Rigidbody getRigidbody()
  {
    return rigidbody;
  }
  
  public void draw()
  {
    rigidbody.draw();
    // rigidbody.drawVoxels();
  }
}

public class BarrelRigidbody extends Rigidbody
{
  /**
   * The size of a voxel used for the buoyancy calculations. Subdivides the cylinder around
   * the barrel into <code>VOXEL_CYLINDER_SIZE / VOXEL_SIZE</code> voxels per side.
   */
  private static final float VOXEL_SIZE = 25f;
  
  /**
   * The radius and height of our voxel cylinder.
   * Note: This value is hard-coded and based on the shape of our barrel. The barrel fits
   * inside a 200x200x200 cube.
   */
  private static final float VOXEL_CYLINDER_SIZE = 200;
  
  /**
   * The actual amount of voxels per side we have to store.
   */
  private static final int VOXEL_COUNT = (int) (VOXEL_CYLINDER_SIZE / VOXEL_SIZE);
  
  /**
   * Our voxel grid, no element in here is ever null, though voxels might be set to invalid
   * if they're not part of our physics calculations.
   */
  private final Voxel[][][] voxels;
  
  /**
   * The amount of valid voxels we have. Required to determine the amount of force each voxel
   * applies to our barrel.
   */
  private int validVoxels = 0;
  
  public BarrelRigidbody(PVector position)
  {
    super(barrelShape, position);
    
    voxels = new Voxel[VOXEL_COUNT][VOXEL_COUNT][VOXEL_COUNT];
    initializeVoxels();
    
    setMass(30f);
    
    PhysicsManager.registerRigidbody(this);
  }
  
  public synchronized void drawVoxels()
  {
    for (int x = 0; x < VOXEL_COUNT; x++)
    {
      for (int y = 0; y < VOXEL_COUNT; y++)
      {
        for (int z = 0; z < VOXEL_COUNT; z++)
        {
          if (!voxels[x][y][z].isValid())
          {
            continue;
          }
          
          pushMatrix();
          
          PVector worldPosition = transformLocalPosition(voxels[x][y][z].getPosition());
          translate(worldPosition.x, worldPosition.y, worldPosition.z);
          box(VOXEL_SIZE - 1);
          
          popMatrix();
        }
      }
    }
  }
  
  /**
   * Since we need to do our own heavy physics calculations, integrateForces has to be overwritten.
   * This is also the reason why we overwrite our rigidbody. I've restrained from calling
   * it FloatingRigidbody since this specifically applies to our barrel shape, mostly due
   * to the voxelization we do.
   */
  @Override
  public void integrateForces()
  {
    // We calculate the volume and density of our barrel first.
    // Note that we have to factor down the size by the force scale here to stay accurate.
    float volume = PI * (VOXEL_CYLINDER_SIZE / FORCE_SCALE / 2f) * (VOXEL_CYLINDER_SIZE / FORCE_SCALE / 2f) * VOXEL_CYLINDER_SIZE / FORCE_SCALE;
    float density = volume * inverseMass;
    
    // This is the amount of force each voxel applies to our barrel.
    float forcePerVoxel = (1f - density) / validVoxels;
    float submergedVolume = 0f;
    
    // We have to perform the following calculations for each individual valid voxel.
    for (int x = 0; x < VOXEL_COUNT; x++)
    {
      for (int y = 0; y < VOXEL_COUNT; y++)
      {
        for (int z = 0; z < VOXEL_COUNT; z++)
        {
          Voxel targetVoxel = voxels[x][y][z];
          if (!targetVoxel.isValid())
          {
            continue;
          }
          
          // We transform the voxel's position into world space and get the water height.
          PVector worldPosition = transformLocalPosition(targetVoxel.getPosition());
          float waterHeight = sampleOceanY(worldPosition.x, worldPosition.z);
          
          // From there on we calculate the depth of the voxel and how much of it is
          // approximately submerged. The depth measures to the top of the voxel.
          // Remember, y is inverted for some processing reason!
          float depth = worldPosition.y - waterHeight + VOXEL_SIZE;
          float submergedPercentage = constrain(depth / VOXEL_SIZE, 0f, 1f);
          
          // We now add the submerged percentage to the submerged volume.
          submergedVolume += submergedPercentage;
          
          // The deeper we are, the bigger the displacement. Except for above the
          // water, where we don't displace at all.
          float displacement = max(depth, 0);
          
          // We now calculate the force that we apply to the rigidbody.
          PVector force = new PVector(0, -9.81f, 0);
          force.mult(displacement * forcePerVoxel);
          
          // And we apply it orientation-based from our voxel position.
          addForceAtPoint(force, worldPosition);
        }
      }
    }
    
    // In order to obtain the total percentage of submerged volume we just divide by
    // the amount of valid voxels we have.
    submergedVolume /= validVoxels;
    
    setLinearDamping(lerp(0.0f, 1.0f, submergedVolume));
    setAngularDamping(lerp(0.05f, 1.0f, submergedVolume));
    
    // We update our rigidbody data as the last thing we do, in order to apply our calculations
    // immediately.
    super.integrateForces();
  }
  
  /**
   * Initializes our voxel grid. Voxels are in position relative to the barrel itself, though to scale.
   * That means that one of the corners of the box we span is at (-100, -100, -100) for example.
   */
  private void initializeVoxels()
  {
    for (int x = 0; x < VOXEL_COUNT; x++)
    {
      for (int y = 0; y < VOXEL_COUNT; y++)
      {
        for (int z = 0; z < VOXEL_COUNT; z++)
        {
          float localX = ((VOXEL_SIZE - VOXEL_CYLINDER_SIZE) / 2f) + (x * VOXEL_SIZE);
          float localY = ((VOXEL_SIZE - VOXEL_CYLINDER_SIZE) / 2f) + (y * VOXEL_SIZE);
          float localZ = ((VOXEL_SIZE - VOXEL_CYLINDER_SIZE) / 2f) + (z * VOXEL_SIZE);
          
          boolean valid = localX * localX + localZ * localZ < (VOXEL_CYLINDER_SIZE / 2) * (VOXEL_CYLINDER_SIZE / 2);
          voxels[x][y][z] = new Voxel(new PVector(localX, localY, localZ), valid);
          
          if (valid)
          {
            validVoxels++;
          }
        }
      }
    }
  }
  
  /**
   * A small struct that holds data over its local position and whether or not it's included in calculations.
   *
   * @author HERE_YOUR_FULL_NAME_TODO
   */
  private class Voxel
  {
    /**
     * The local position, relative to our barrel.
     */
    private final PVector position;
    
    /**
     * Whether or not this voxel is valid for the physics calculations. If it's not then it's outside
     * the voxel cylinder's bounds.
     */
    private final boolean valid;
    
    /**
     * Constructs a new voxel at the given position with whether or not the voxel is valid for our
     * buoyancy calculations.
     *
     * @param position The model-local position.
     * @param valid Whether or not the voxel is valid.
     */
    public Voxel(PVector position, boolean valid)
    {
      this.position = position;
      this.valid = valid;
    }
    
    /**
     * The model-local position. Needs to be transformed to world position first for use.
     *
     * @returns The model-local position of this voxel.
     */
    public PVector getPosition()
    {
      return position;
    }
    
    /**
     * The voxel is valid for our calculations if it is inside the cylinder defining our barrel.
     *
     * @returns Whether or not this voxel is valid for calculations.
     */
    public boolean isValid()
    {
      return valid;
    }
  }
}
