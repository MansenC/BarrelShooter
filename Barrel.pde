import java.util.ArrayList;
import java.util.List;
import java.util.Random;

PShape barrelShape;
PShape hitIndicator;

/**
 * Handles the spawning and updating of all barrels in the world.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class BarrelManager
{
  /**
   * The starting position of barrel spawning. This is the smaller circle of the spawning area.
   */
  private static final float BARREL_SPAWN_X_START = 40;
  
  /**
   * The ending position of barrel spawning. This is the larger circle of the spawning area.
   */
  private static final float BARREL_SPAWN_X_END = 90;
  
  /**
   * The maximum (and inverted minimum) angle of difference at which barrels can spawn.
   */
  private static final float BARREL_SPAWN_Y_ANGLE = 40f;
  
  /**
   * The minimum distance between two barrels (X/Z).
   */
  private static final float BARREL_MIN_DISTANCE = 4f;
  
  /**
   * The cannon origin describes the center point of the circles that describe the boundary
   * of where barrels can spawn in the water.
   */
  private final PVector cannonOrigin;
  
  /**
   * The list of all barrels that currently are being displayed.
   */
  private final List<Barrel> barrels = new ArrayList<>();
  
  /**
   * The rigidbody mass of a barrel. Default is 2,000kg
   */
  private float currentBarrelWeight = BARREL_WEIGHT_DEFAULT;
  
  /**
   * Constructs the barrel manager with its origin around which the barrels spawn
   * in a cone.
   */
  public BarrelManager(PVector origin)
  {
    cannonOrigin = origin;
  }
  
  /**
   * Updates the weight of all barrels to the provided amount. Will affect physics.
   *
   * @param newWeight the new weight of the barrels in kg.
   */
  public void setBarrelWeight(float newWeight)
  {
    if (newWeight == 0)
    {
      return;
    }
    
    currentBarrelWeight = newWeight;
    for (Barrel barrel : barrels)
    {
      barrel.getRigidbody().setMass(newWeight);
    }
  }
  
  /**
   * Returns the amount of barrels spawned in this world.
   *
   * @returns The amount of barrels.
   */
  public int getBarrelCount()
  {
    return barrels.size();
  }
  
  /**
   * Clears all barrels from physics calculations and rendering.
   */
  public void clearBarrels()
  {
    for (Barrel barrel : barrels)
    {
      PhysicsManager.removeRigidbody(barrel.getRigidbody());
    }
    
    barrels.clear();
  }
  
  /**
   * Spawns a given amount of barrels in a cone that is originating from the provided origin
   * in the BarrelManager's constructor.
   *
   * @param amount The amount of barrels to spawn.
   */
  public void spawnBarrels(int amount)
  {
    // We have an upper limit on attempts if the barrel amount is too large for the area we have.
    int attemptsRemaining = amount * amount;
    
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
        attemptsRemaining--;
        if (attemptsRemaining == 0)
        {
          // We've run out of attempts. Let's leave it here.
          break;
        }
        
        // We have failed the distance check. Let's try again.
        continue;
      }
      
      // If not then we calculate the current ocean height and adjust the barrel's starting Y position accordingly.
      targetPosition.y = sampleOceanY(targetPosition.x, targetPosition.z);
      barrels.add(new Barrel(targetPosition, currentBarrelWeight));
    }
  }
  
  /**
   * Updates and draws all barrels.
   */
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
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class Barrel
{
  /**
   * The rigidbody associated with a barrel. Specifically handles buoyancy.
   */
  private final BarrelRigidbody rigidbody;
  
  /**
   * Constructs a new barrel at the given world position with the provided initial weight.
   *
   * @param position The position to spawn at.
   * @param weight The initial weight of the barrel.
   */
  public Barrel(PVector position, float weight)
  {
    rigidbody = new BarrelRigidbody(position);
    rigidbody.setMass(weight);
  }
  
  /**
   * Returns the rigidbody managing this barrel's physics.
   *
   * @returns The managing rigidbody.
   */
  public Rigidbody getRigidbody()
  {
    return rigidbody;
  }
  
  /**
   * Draws the barrel. If drawVoxels is enabled, will display the individual voxels used
   * for the calculation of the buoyancy simulation.
   */
  public void draw()
  {
    rigidbody.draw();
    // rigidbody.drawVoxels();
  }
}

/**
 * This rigidbody override is specifically designed to calculate the buoyancy forces of a cylindrical
 * shape. With voxelization adjusted it will support any shape possible.
 * The forces are calculated using archimedes' law. 
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class BarrelRigidbody extends Rigidbody
{
  /**
   * The size of a voxel used for the buoyancy calculations. Subdivides the cylinder around
   * the barrel into <code>VOXEL_CYLINDER_SIZE / VOXEL_SIZE</code> voxels per side.
   */
  private static final float VOXEL_SIZE = .25f;
  
  /**
   * The radius and height of our voxel cylinder.
   * Note: This value is hard-coded and based on the shape of our barrel. The barrel fits
   * inside a 200x200x200 cube.
   */
  private static final float VOXEL_CYLINDER_SIZE = 2;
  
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
  
  /**
   * Whether or not this rigidbody already has been hit by something.
   */
  private boolean hit = false;
  
  /**
   * Constructs the rigidbody at the given position and initializes the rigidbody-specific voxelization.
   *
   * @param position The initial position.
   */
  public BarrelRigidbody(PVector position)
  {
    super(barrelShape, new CylinderShape(2, 1), position);
    
    voxels = new Voxel[VOXEL_COUNT][VOXEL_COUNT][VOXEL_COUNT];
    initializeVoxels();
    
    PhysicsManager.registerRigidbody(this);
  }
  
  /**
   * Debug functionality, used to display each voxel individually. This displays the shape
   * that is used for calculating the forces, with a small reduction in voxel size for displaying
   * purposes.
   */
  public synchronized void drawVoxels()
  {
    // We just iterate through our 3d voxel grid.
    for (int x = 0; x < VOXEL_COUNT; x++)
    {
      for (int y = 0; y < VOXEL_COUNT; y++)
      {
        for (int z = 0; z < VOXEL_COUNT; z++)
        {
          // Any non-valid voxel isn't used in calculations so we don't display them either.
          if (!voxels[x][y][z].isValid())
          {
            continue;
          }
          
          pushMatrix();
          
          // We just transform the local position of our voxel to the world position
          // and translate accordingly. We do however not rotate the voxels since they
          // aren't rotated for the physics calculations either.
          PVector worldPosition = transformLocalPosition(voxels[x][y][z].getPosition());
          translate(worldPosition.x, worldPosition.y, worldPosition.z);
          box(VOXEL_SIZE - .01f);
          
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
    // The density of water. Buoyancy force is defined as rho * g * V
    // where rho is the density, g is the gravitational acceleration and
    // V is the displaced volume.
    // The density of seawater is around 1025 kg per cubic meter.
    float rho = 1025f;
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
          float depth = worldPosition.y - waterHeight;
          float submergedPercentage = constrain(depth / VOXEL_SIZE, 0f, 1f);
          
          // We now add the submerged percentage to the submerged volume.
          submergedVolume += submergedPercentage;
          
          // The displacement is defined as the amount of volume of the voxel that is
          // under water. In other words, it's our voxel volume multiplied by the submerged percentage.
          float displacement = VOXEL_SIZE * VOXEL_SIZE * VOXEL_SIZE * submergedPercentage;
          
          // We now calculate the force that we apply to the rigidbody. Hydrostatic pressure
          // cancels out any non-vertical forces, buoyancy is actually just applied upwards.
          PVector force = new PVector(0, rho * -GRAVITY_ACCELERATION * displacement, 0);
          
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
    
    // Finally we need to calculate the force the ocean applies to our barrel.
    PVector oceanForce = calculateOceanFlowPressure(position.x, position.z);
    addForce(oceanForce);
    
    // We update our rigidbody data as the last thing we do, in order to apply our calculations
    // immediately.
    super.integrateForces();
  }
  
  @Override
  public void onHit()
  {
    if (hit)
    {
      return;
    }
    
    // When we're hit then we display an indicator. It doesn't matter by what thing we're hit, so
    // chaining barrel hits is also a valid strategy, though arguably a lot harder than just hitting
    // a barrel with the cannonball.
    hit = true;
    addChildMesh(hitIndicator);
    ui.barrelHit();
    
    // We also check if it's game over so we don't eventually have to wait until a cannonball is
    // being removed. We check game over after we notify the UI of the hit so we can regain
    // a shot after hitting, even though zero were remaining.
    ui.checkGameOver();
  }
  
  /**
   * Initializes our voxel grid. Voxels are in position relative to the barrel itself, though to scale.
   * That means that one of the corners of the box we span is at (-1, -1, -1) for example.
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
