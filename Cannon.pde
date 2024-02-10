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
   * The minimum vertical angle the cannon can shoot at.
   */
  private static final float CANNON_MIN_VERTICAL_ANGLE = 5;
  
  /**
   * The maximum vertical angle the cannon can shoot at.
   */
  private static final float CANNON_MAX_VERTICAL_ANGLE = 85;
  
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
   * The model for the cannonballs.
   */
  private final PShape cannonball;
  
  /**
   * The cannon ruler image.
   */
  private final PImage cannonRuler;
  
  /**
   * The icon for the cannon.
   */
  private final PImage cannonIcon;
  
  /**
   * The cannon base image.
   */
  private final PImage cannonBase;
  
  /**
   * The available bomb image.
   */
  private final PImage availableBomb;
  
  /**
   * The used bomb image.
   */
  private final PImage usedBomb;
  
  /**
   * The undamaged ship image.
   */
  private final PImage undamagedShip;
  
  /**
   * The damaged ship image.
   */
  private final PImage damagedShip;
  
  /**
   * The current vertical rotation of the cannon barrel. Controls how far the balls will shoot.
   * In range of [5..85].
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
    cannonball = loadShape("Cannonball.obj");
    
    cannonRuler = loadImage("game_ruler.png");
    cannonIcon = loadImage("game_cannon.png");
    cannonBase = loadImage("game_cannon_base.png");
    availableBomb = loadImage("game_bomb_available.png");
    usedBomb = loadImage("game_bomb_used.png");
    undamagedShip = loadImage("game_ship_nodamage.png");
    damagedShip = loadImage("game_ship_damage.png");
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
    
    // Only draw the wagon
    shape(cannonWagon);
    
    pushMatrix();
    
    // We need to rotate and translate the cannon so that the metal beam stays fixed in place
    // relative to its wagon.
    float radiansAngle = (cannonVerticalRotation - 90) * PI / 180;
    translate(100 * sin(radiansAngle), 100 * (1 - cos(radiansAngle)), 0);
    rotateZ(radiansAngle);
    
    // The scope should be on the upper side.
    rotateY(PI);
    shape(cannon);
    
    popMatrix();
    
    if (!camera.isFreecam())
    {
      handleUserInput();
      
      camera.setPitch(25);
      camera.setPosition(
        modelX(-200, 400, 0),
        modelY(-200, 400, 0),
        modelZ(-200, 400, 0));
    }
    
    popMatrix();
    
    drawGUI();
  }
  
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
    
    cannonVerticalRotation = constrain(cannonVerticalRotation, CANNON_MIN_VERTICAL_ANGLE, CANNON_MAX_VERTICAL_ANGLE);
  }
  
  private void drawGUI()
  {
    if (camera.isFreecam())
    {
      return;
    }
    
    hint(DISABLE_DEPTH_TEST);
    noLights();
    
    pushMatrix();
    camera.applyGUITransformations();
    
    for (int i = 0; i < 10; i++)
    {
      // Draw the bombs on the left side of the screen so that it takes up half the height,
      // is centered around Y and has a 10% gap to the left.
      drawUIImage(
        availableBomb,
        width / 10f,
        height / 4f + (height / 20f) * i,
        height / 20f,
        height / 20f);
    }
    
    for (int i = 0; i < 5; i++)
    {
      // Draw the ships on the right side of the screen so that it takes up half the height,
      // is centered around Y and has a 10% gap to the right. Ships are 64x48 so their aspect
      // ratio is 4:3, which is why the width is multiplied by that.
      drawUIImage(
        undamagedShip,
        width - (7f / 3f) * height / 10f,
        height / 4f + (height / 10f) * i,
        (4f / 3f) * height / 10f,
        height / 10f);
    }
    
    // We then draw the cannon indicator. This one is aligned so that there's 10% margin
    // to the right of the screen and the same distance to the bottom.
    drawUIImage(
      cannonRuler,
      width - (width / 10f) - (height / 20f),
      height - (width / 10f) - (height / 20f),
      height / 7f,
      height / 7f);
      
    pushMatrix();
    
    // Modify the transformation so we can freely rotate the indicator like the cannon is being rotated.
    translate(
      width - (width / 10f) - (height / 20f) + (2f / 3f) * height / 7f,
      height - (width / 10f) - (height / 20f) + (2f / 3f) * height / 7f,
      0);
    rotateZ(radians(cannonVerticalRotation));
    
    // After that pain, we draw it offset so that the middle right edge is centered on the origin.
    drawUIImage(cannonIcon, -height / 7f, -(1f / 3f) * height / 7f, height / 7f, (2f / 3f) * height / 7f);
    
    popMatrix();
    
    drawUIImage(
      cannonBase,
      width - (width / 10f) - (height / 20f) + ((1f / 4f) * height / 7f),
      height - (width / 10f) - (height / 20f) + ((1f / 4f) * height / 7f),
      (3f / 4f) * height / 7f,
      (3f / 4f) * height / 7f);
    
    popMatrix();
    hint(ENABLE_DEPTH_TEST);
    environment.restoreLights();
  }
  
  private void drawUIImage(PImage image, float x, float y, float width, float height)
  {
    beginShape();
    texture(image);
    
    vertex(x, y, 0, 0);
    vertex(x + width, y, 1, 0);
    vertex(x + width, y + height, 1, 1);
    vertex(x, y + height, 0, 1);
    
    endShape();
  }
}
