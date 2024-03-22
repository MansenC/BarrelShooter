import java.awt.Font;
import java.util.function.Consumer;
import g4p_controls.*;

/**
 * The default value for the amount of barrels spawned. The more barrels the laggier the rendering
 * of processing.
 */
public static final int BARREL_AMOUNT_DEFAULT = 10;

/**
 * The default mass of a barrel, 2,000kg.
 */
public static final float BARREL_WEIGHT_DEFAULT = 2000f;

/**
 * The default weight of a cannonball, 200kg. This is quite a lot for a cannonball.
 */
public static final float CANNONBALL_WEIGHT_DEFAULT = 200f;

/**
 * The default force of a cannonball, being 280kN, which equates to a default
 * acceleration for the cannonball of 1,400m/s².
 */
public static final float CANNONBALL_FORCE_DEFAULT = 280_000f;

/**
 * The default wave speed. This dictates how fast the ocean evolves. This is an arbitrary value
 * chosen to look good.
 */
public static final float WAVE_SPEED_DEFAULT = 0.05f;

/**
 * The default wave scale. The scale is determined by the size of the ocean near plane which is 100mx100m in surface area.
 * Therefor, the default wave scale is 2*2m for peaks and dips in total, if the amplitude for a wave is set to 1.
 * Again a value chosen to look good.
 */
public static final float WAVE_SCALE_DEFAULT = 0.02f;

/**
 * The amplitudes for a given wave. The ocean uses the sum-of-sines to calculate its wave pattern. Each amplitude corresponds
 * to a sine wave layer that is controled by the provided amplitude and frequency. The higher the amplitude, the higher the
 * targeted layer's wave.
 */
public static final float[] WAVE_AMPLITUDES_DEFAULT = new float[] { 1f, 0.5f, 0.5f, 0.25f };

/**
 * Affects the layers of the sum-of-sine just like the amplitude, only with the frequency. The higher the frequency, the shorter
 * the wave. The limit to this is the amount of subdivisions of the ocean.
 */
public static final float[] WAVE_FREQUENCIES_DEFAULT = new float[] { 1.0f / 2.0f, 1.0f / 4.0f, 1.0f / 8.0f, 1.0f / 10.0f };

/**
 * Manages every UI component. The UI is split into two parts, the UI we render ourselves - the minigame UI -
 * and the options UI. No UI library provides a simple image component which is all I need for rendering the
 * minigame UI, therefore we do it ourselves with a simple camera transformation and some quads.
 * The options UI, however, requires a more complex system that the user can interact with, and most importantly
 * text rendering. Here I simply use the G4P library to do the heavy lifting.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class UI
{
  /**
   * The group managing every single debug UI component.
   */
  private final GGroup uiGroup;
  
  /**
   * The label that renders the text over the cannon indicator, displaying its vertical rotation.
   */
  private final GLabel cannonDegrees;
  
  /**
   * A group used to control the game won text.
   */
  private final GGroup gameWon;
  
  /**
   * A group used to control the game lost text.
   */
  private final GGroup gameLost;
  
  /**
   * The current text for the amount of barrels as dictated by user input.
   */
  private String currentBarrelsAmountText = Integer.toString(BARREL_AMOUNT_DEFAULT);
  
  /**
   * The current text for the weight of barrels as dictated by user input.
   */
  private String currentBarrelWeightText = Float.toString(BARREL_WEIGHT_DEFAULT);
  
  /**
   * The current text for the weight of cannonballs as dictated by user input.
   */
  private String currentCannonballWeightText = Float.toString(CANNONBALL_WEIGHT_DEFAULT);
  
  /**
   * The current text for the force of the cannon as dictated by user input.
   */
  private String currentCannonForceText = Float.toString(CANNONBALL_FORCE_DEFAULT);
  
  /**
   * The current text for the speed of ocean waves as dictated by user input.
   */
  private String currentWaveSpeedText = Float.toString(WAVE_SPEED_DEFAULT);
  
  /**
   * The current text for the scale of ocean waves as dictated by user input.
   */
  private String currentWaveScaleText = Float.toString(WAVE_SCALE_DEFAULT);
  
  /**
   * The amplitudes text fields for reference on user input changes.
   */
  private final GTextField[] waveAmplitudes = new GTextField[4];
  
  /**
   * The current texts for the individual wave amplitudes as dictated by user input.
   */
  private String[] currentWaveAmplitudesTexts = new String[]
  {
    Float.toString(WAVE_AMPLITUDES_DEFAULT[0]),
    Float.toString(WAVE_AMPLITUDES_DEFAULT[1]),
    Float.toString(WAVE_AMPLITUDES_DEFAULT[2]),
    Float.toString(WAVE_AMPLITUDES_DEFAULT[3])
  };
  
  /**
   * The frequencies text fields for reference on user input changes.
   */
  private final GTextField[] waveFrequencies = new GTextField[4];
  
  /**
   * The current texts for the individual wave frequencies as dictated by user input.
   */
  private String[] currentWaveFrequenciesTexts = new String[]
  {
    Float.toString(WAVE_FREQUENCIES_DEFAULT[0]),
    Float.toString(WAVE_FREQUENCIES_DEFAULT[1]),
    Float.toString(WAVE_FREQUENCIES_DEFAULT[2]),
    Float.toString(WAVE_FREQUENCIES_DEFAULT[3])
  };
  
  /**
   * Whether or not the options UI is currently visible.
   */
  private boolean visible = false;
  
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
   * The shots a user has in total. Always two times the amount of barrels.
   */
  private int shotsTotal = 2 * BARREL_AMOUNT_DEFAULT;
  
  /**
   * The remaining shots a user has.
   */
  private int shotsAvailable = shotsTotal;
  
  /**
   * The remaining amount of barrels the user still has to hit.
   */
  private int barrelsRemaining = BARREL_AMOUNT_DEFAULT;
  
  /**
   * A timer for resetting the game when a game over is triggered, either by winning or losing.
   */
  private float gameOverTimer = -1;
  
  /**
   * Constructs the UI. Loads the images and creates the options UI using the G4P library.
   */
  public UI()
  {
    G4P.messagesEnabled(false);
    
    uiGroup = new GGroup(BarrelShooter.this, 0);
    
    // Register the game panel which handles settings regarding the minigame itself.
    GPanel gamePanel = new GPanel(BarrelShooter.this, 100, 100, 300, 180, "Game Settings");
    
    registerTextField(gamePanel, 30, "Barrels", currentBarrelsAmountText, "handleBarrelsAmountUpdate");
    registerTextField(gamePanel, 60, "Barrel Weight", currentBarrelWeightText, "handleBarrelWeightUpdate");
    registerTextField(gamePanel, 90, "Cannonball Weight", currentCannonballWeightText, "handleCannonballWeightUpdate");
    registerTextField(gamePanel, 120, "Cannon Force", currentCannonForceText, "handleCannonForceUpdate");
    
    GButton gameUpdate = new GButton(BarrelShooter.this, 225, 150, 50, 20, "Update");
    gameUpdate.addEventHandler(this, "handleGameSettingsUpdateRequested");
    gamePanel.addControl(gameUpdate);
    
    uiGroup.addControl(gamePanel);
    
    // Registers the ocean panel which handles settings regarding the ocean environment.
    GPanel oceanPanel = new GPanel(BarrelShooter.this, 500, 100, 300, 180, "Ocean Settings");
    
    registerTextField(oceanPanel, 30, "Wave Speed", currentWaveSpeedText, "handleWaveSpeedUpdate");
    registerTextField(oceanPanel, 60, "Wave Scale", currentWaveScaleText, "handleWaveScaleUpdate");
    registerVec4Input(oceanPanel, 90, "Amplitudes", waveAmplitudes, currentWaveAmplitudesTexts, "handleWaveAmplitudesUpdate");
    registerVec4Input(oceanPanel, 120, "Frequencies", waveFrequencies, currentWaveFrequenciesTexts, "handleWaveFrequenciesUpdate");
    
    GButton oceanUpdate = new GButton(BarrelShooter.this, 225, 150, 50, 20, "Update");
    oceanUpdate.addEventHandler(this, "handleOceanSettingsUpdateRequested");
    oceanPanel.addControl(oceanUpdate);
    
    uiGroup.addControl(oceanPanel);
    
    // Load all our images
    cannonRuler = loadImage("game_ruler.png");
    cannonIcon = loadImage("game_cannon.png");
    cannonBase = loadImage("game_cannon_base.png");
    availableBomb = loadImage("game_bomb_available.png");
    usedBomb = loadImage("game_bomb_used.png");
    undamagedShip = loadImage("game_ship_nodamage.png");
    damagedShip = loadImage("game_ship_damage.png");
    
    // Construct the non-options UI related G4P controls.
    cannonDegrees = new GLabel(BarrelShooter.this, width - (width / 10f) + (width / 80f), height - (width / 10f), 100, 100, "-5°");
    cannonDegrees.setFont(new Font("Arial", Font.BOLD, 40));
    
    GLabel wonLabel = new GLabel(BarrelShooter.this, width / 4, height / 4, width / 2, height / 2, "You won. Congratulations!");
    wonLabel.setFont(new Font("Arial", Font.BOLD, width / 15));
    wonLabel.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
    
    gameWon = new GGroup(BarrelShooter.this, 0);
    gameWon.addControl(wonLabel);
    
    GLabel lostLabel = new GLabel(BarrelShooter.this, width / 4, height / 4, width / 2, height / 2, "You lost. Try again!");
    lostLabel.setFont(new Font("Arial", Font.BOLD, width / 15));
    lostLabel.setTextAlign(GAlign.CENTER, GAlign.MIDDLE);
    
    gameLost = new GGroup(BarrelShooter.this, 0);
    gameLost.addControl(lostLabel);
  }
  
  /**
   * Whether or not the game is completed. This is true when there are either no shots available anymore
   * or all barrels have been hit.
   *
   * @returns True if the game is completed.
   */
  public boolean isGameCompleted()
  {
    return shotsAvailable <= 0 || barrelsRemaining <= 0;
  }
  
  /**
   * Removes a bomb from the amount of shots available.
   */
  public void removeBomb()
  {
    shotsAvailable--;
  }
  
  /**
   * Hits a barrel. Whenever a barrel is hit, a shot is added to the amount of shots available, maxing
   * out at the maximum shots available.
   */
  public void barrelHit()
  {
    barrelsRemaining--;
    shotsAvailable = min(shotsTotal, shotsAvailable + 1);
  }
  
  /**
   * Checks whether or not a game over is triggered. Whenever that is the case,
   * the appropriate text is displayed and the game over timer is started.
   * When this timer runs out, the minigame is reset with the targeted amount
   * of barrels.
   */
  public void checkGameOver()
  {
    if (gameOverTimer >= 0 || (barrelsRemaining > 0 && shotsAvailable > 0))
    {
      return;
    }
    
    if (barrelsRemaining == 0)
    {
      gameWon.fadeIn(0, 500);
    }
    else
    {
      gameLost.fadeIn(0, 500);
    }
    
    gameOverTimer = 5;
  }
  
  /**
   * Draws the GUI for the cannon game. The GUI includes indicators about how many shots remain,
   * how many barrels have been destroyed and the current angle of the cannon. Will not draw in freecam mode.
   * The GUI uses the camera's {@link Camera#applyGUITransformations} method in order to draw properly.
   */
  public void drawMinigameGUI()
  {
    if (camera.isFreecam())
    {
      return;
    }
    
    // We disable depth testing and shading so that we always draw
    // fully lit and on top.
    hint(DISABLE_DEPTH_TEST);
    noLights();
    
    pushMatrix();
    camera.applyGUITransformations();
    
    // The bomb rows start at 5% from the left side, which equals to width / 20f.
    int maxBombsPerColumn = 20;
    float bombSize = max(height / (2f * maxBombsPerColumn), height / (2f * shotsTotal));
    int bombColumns = ceil((2f * shotsTotal * bombSize) / height);
    
    // We draw bombs in columns of max. 20 - if we have less than 20 bombs to draw then we
    // scale the first column up so it matches the height of half the screen.
    for (int column = 0; column < bombColumns; column++)
    {
      // We offset each column from 5% left by the amount of columns previous.
      float columnX = (width / 20f) + bombSize * column;
      // And we determine the amount of bombs to draw this column, which at max is 20.
      int bombDrawCount = min(maxBombsPerColumn, shotsTotal - maxBombsPerColumn * column);
      
      for (int row = 0; row < bombDrawCount; row++)
      {
        boolean isUsedBomb = column * maxBombsPerColumn + row >= shotsAvailable;
        drawUIImage(
          isUsedBomb ? usedBomb : availableBomb,
          columnX,
          height / 4f + bombSize * row,
          bombSize,
          bombSize);
      }
    }
    
    // The amount of ships is shotsTotal / 2.
    int maxShipsPerColumn = 10;
    float shipSize = max(height / (2f * maxShipsPerColumn), height / shotsTotal);
    int shipColumns = ceil((shotsTotal * shipSize) / height);
    
    // We essentially do the same for all ships as we do for the bombs, except for
    // that we're working right-to-left.
    for (int column = 0; column < shipColumns; column++)
    {
      // Important to note is that we take width - width / 20f, which is the x value
      // for the _right_ side of the image. This is why we add one to the column
      // so we get the value for the left side of the image. Aspect ratio for the
      // ship images is 4/3.
      float columnX = width - (width / 20f) - (4f / 3f) * shipSize * (column + 1);
      int shipDrawCount = min(maxShipsPerColumn, shotsTotal / 2 - maxShipsPerColumn * column);
      for (int row = 0; row < shipDrawCount; row++)
      {
        boolean isSunkenShip = column * maxShipsPerColumn + row >= barrelsRemaining;
        drawUIImage(
          isSunkenShip ? damagedShip : undamagedShip,
          columnX,
          height / 4f + shipSize * row,
          (4f / 3f) * shipSize,
          shipSize);
      }
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
    rotateZ(radians(cannon.getCannonVerticalRotation()));
    
    // After that pain, we draw it offset so that the middle right edge is centered on the origin.
    drawUIImage(cannonIcon, -height / 7f, -(1f / 3f) * height / 7f, height / 7f, (2f / 3f) * height / 7f);
    
    popMatrix();
    
    // Finally we draw the cover.
    drawUIImage(
      cannonBase,
      width - (width / 10f) - (height / 20f) + ((1f / 4f) * height / 7f),
      height - (width / 10f) - (height / 20f) + ((1f / 4f) * height / 7f),
      (3f / 4f) * height / 7f,
      (3f / 4f) * height / 7f);
    
    popMatrix();
    hint(ENABLE_DEPTH_TEST);
    environment.restoreLights();
    
    // We now update our G4P widgets, mostly the cannon degree indicator.
    String cannonText;
    if (cannon.getCannonVerticalRotation() < 0)
    {
      cannonText = String.format("%d°", (int) floor(cannon.getCannonVerticalRotation()));
    }
    else
    {
      cannonText = String.format("%02d°", (int) cannon.getCannonVerticalRotation());
    }
    
    cannonDegrees.setText(cannonText);
    
    // If we have a rollover on the game over timer then we have to reset our game.
    boolean wasPositive = gameOverTimer > 0;
    gameOverTimer -= deltaTime;
    if (!wasPositive || gameOverTimer >= 0)
    {
      return;
    }
    
    gameOverTimer = -1;
    gameLost.fadeOut(0, 100);
    gameWon.fadeOut(0, 100);
    
    resetGame(true);
  }
  
  /**
   * Toggles the visibility of the options UI and unlocks the cursor.
   */
  public void toggleVisibility()
  {
    visible = !visible;
    if (visible != paused)
    {
      togglePaused();
    }
    
    camera.setCursorLocked(!visible);
    if (visible)
    {
      uiGroup.fadeIn(0, 200);
    }
    else
    {
      uiGroup.fadeOut(0, 200);
    }
  }
  
  /**
   * Returns true when the options UI is visible.
   *
   * @returns Whether or not the options UI is visible.
   */
  public boolean isVisible()
  {
    return visible;
  }
  
  /**
   * Handles a request for updating the game settings. Triggers a reset to the minigame when the amount
   * of barrels has been changed.
   *
   * @param button The button clicked.
   * @param event The event type. We only accept click-events.
   */
  public void handleGameSettingsUpdateRequested(@SuppressWarnings("unused") GButton button, GEvent event)
  {
    if (event != GEvent.CLICKED)
    {
      return;
    }
    
    barrelManager.setBarrelWeight(getValueOrDefault(currentBarrelWeightText, BARREL_WEIGHT_DEFAULT));
    cannonballForce = getValueOrDefault(currentCannonForceText, CANNONBALL_FORCE_DEFAULT);
    cannonballWeight = getValueOrDefault(currentCannonballWeightText, CANNONBALL_WEIGHT_DEFAULT);
    
    resetGame(false);
  }
  
  /**
   * Handles a request for updating the ocean environment.
   *
   * @param button The button clicked.
   * @param event The event type. We only accept click-events.
   */
  public void handleOceanSettingsUpdateRequested(@SuppressWarnings("unused") GButton button, GEvent event)
  {
    if (event != GEvent.CLICKED)
    {
      return;
    }
    
    oceanWaveSpeed = getValueOrDefault(currentWaveSpeedText, WAVE_SPEED_DEFAULT);
    oceanWaveScale = getValueOrDefault(currentWaveScaleText, WAVE_SCALE_DEFAULT);
    
    for (int i = 0; i < WAVE_AMPLITUDES_DEFAULT.length; i++)
    {
      oceanWaveAmplitudes[i] = getValueOrDefault(currentWaveAmplitudesTexts[i], WAVE_AMPLITUDES_DEFAULT[i]);
    }
    
    for (int i = 0; i < WAVE_FREQUENCIES_DEFAULT.length; i++)
    {
      oceanWaveFrequencies[i] = getValueOrDefault(currentWaveFrequenciesTexts[i], WAVE_FREQUENCIES_DEFAULT[i]);
    }
  }
  
  /**
   * Handles an input event for the amount of barrels. Will validate if the text input
   * was a valid integer, an empty input of a plain minus sign. If not then the
   * text is rolled back to the previous state.
   *
   * @param input The text field for this event.
   * @param event The event type. We only accept text change events.
   */
  public void handleBarrelsAmountUpdate(GTextField input, GEvent event)
  {
    // This function stands alone since it validates integers only. The other ones all want floats.
    if (event != GEvent.CHANGED)
    {
      return;
    }
    
    String newInput = input.getText();
    if (newInput.trim().isEmpty() || "-".equals(newInput))
    {
      // If the input is removed completely or a minus sign then we don't care.
      // We handle this as the default value.
      currentBarrelsAmountText = newInput.trim();
      return;
    }
    
    try
    {
      // If this passes through then we have a valid integer format.
      Integer.parseInt(newInput);
      currentBarrelsAmountText = newInput;
    }
    catch (NumberFormatException ex)
    {
      // If not then we roll back to the last valid value.
      input.setText(currentBarrelsAmountText);
      
      // This workaround is important. If we do not lose and then gain focus again after a wrong input, the program
      // would just crash due to a NullPointerException in the UI library. For some reason it expects a selection
      // and this selects the whole text for us.
      input.setFocus(false);
      input.setFocus(true);
    }
  }
  
  /**
   * Handles the input change for barrel weight.
   *
   * @param input The text field for this event.
   * @param event The event type. We only accept text change events.
   */
  public void handleBarrelWeightUpdate(GTextField input, GEvent event)
  {
    handleFloatInputUpdate(input, event, currentBarrelWeightText, text -> currentBarrelWeightText = text);
  }
  
  /**
   * Handles the input change for cannonball weight.
   *
   * @param input The text field for this event.
   * @param event The event type. We only accept text change events.
   */
  public void handleCannonballWeightUpdate(GTextField input, GEvent event)
  {
    handleFloatInputUpdate(input, event, currentCannonballWeightText, text -> currentCannonballWeightText = text);
  }
  
  /**
   * Handles the input change for cannon force.
   *
   * @param input The text field for this event.
   * @param event The event type. We only accept text change events.
   */
  public void handleCannonForceUpdate(GTextField input, GEvent event)
  {
    handleFloatInputUpdate(input, event, currentCannonForceText, text -> currentCannonForceText = text);
  }
  
  /**
   * Handles the input change for wave speed.
   *
   * @param input The text field for this event.
   * @param event The event type. We only accept text change events.
   */
  public void handleWaveSpeedUpdate(GTextField input, GEvent event)
  {
    handleFloatInputUpdate(input, event, currentWaveSpeedText, text -> currentWaveSpeedText = text);
  }
  
  /**
   * Handles the input change for wave scale.
   *
   * @param input The text field for this event.
   * @param event The event type. We only accept text change events.
   */
  public void handleWaveScaleUpdate(GTextField input, GEvent event)
  {
    handleFloatInputUpdate(input, event, currentWaveScaleText, text -> currentWaveScaleText = text);
  }
  
  /**
   * Handles the input change for a wave amplitude text field.
   *
   * @param input The text field for this event.
   * @param event The event type. We only accept text change events.
   */
  public void handleWaveAmplitudesUpdate(GTextField input, GEvent event)
  {
    handleVec4FloatInputUpdate(input, event, waveAmplitudes, currentWaveAmplitudesTexts);
  }
  
  /**
   * Handles the input change for a wave frequency text field.
   *
   * @param input The text field for this event.
   * @param event The event type. We only accept text change events.
   */
  public void handleWaveFrequenciesUpdate(GTextField input, GEvent event)
  {
    handleVec4FloatInputUpdate(input, event, waveFrequencies, currentWaveFrequenciesTexts);
  }
  
  /**
   * Matches the text field with the target layer index and updates its value in the array,
   * if validated to be a valid floating point value.
   *
   * @param input The target text field.
   * @param event The event type. We only accept text change events.
   * @param inputs The text fields to match against.
   * @param currentValues The last known values of all text fields provided in inputs.
   */
  private void handleVec4FloatInputUpdate(GTextField input, GEvent event, GTextField[] inputs, String[] currentValues)
  {
    if (event != GEvent.CHANGED)
    {
      return;
    }
    
    int index;
    for (index = 0; index < inputs.length; index++)
    {
      if (inputs[index] != input)
      {
        continue;
      }
      
      break;
    }
    
    // Gotta love Java for this. Yes, that line is required because of lambda weirdness.
    int finalIndex = index;
    handleFloatInputUpdate(input, event, currentValues[index], text -> currentValues[finalIndex] = text);
  }
  
  /**
   * Validates the new input on a given text field to be a valid floating point number,
   * an empty input field, a single minus sign, a single decimal point or a minus
   * sign followed by a decimal point. Anything else is rejected and rolled back
   * to the previous value as provided. Whenever a change is accepted, the onUpdate
   * consumer is invoked.
   *
   * @param input The text field that was changed.
   * @param event The event type. We only accept text change events.
   * @param oldValue The previous value for this text field.
   * @param onUpdate A consumer handling the value update with the new updated value.
   */
  private void handleFloatInputUpdate(GTextField input, GEvent event, String oldValue, Consumer<String> onUpdate)
  {
    if (event != GEvent.CHANGED)
    {
      return;
    }
    
    String newInput = input.getText();
    if (newInput.trim().isEmpty()
      || "-".equals(newInput)
      || ".".equals(newInput)
      || "-.".equals(newInput))
    {
      // If the input is one of the previous inputs then we have to handle it specially.
      // Float.parseFloat accepts number formats like 0. so we do not have to handle
      // anything alike.
      onUpdate.accept(newInput.trim());
      return;
    }
    
    try
    {
      // If this passes through then we have a valid float format.
      Float.parseFloat(newInput);
      onUpdate.accept(newInput);
    }
    catch (NumberFormatException ex)
    {
      // If not then we roll back to the last valid value.
      input.setText(oldValue);
      
      // This workaround is important. If we do not lose and then gain focus again after a wrong input, the program
      // would just crash due to a NullPointerException in the UI library. For some reason it expects a selection
      // and this selects the whole text for us.
      input.setFocus(false);
      input.setFocus(true);
    }
  }
  
  /**
   * Attempts to parse the provided value to a floating point number and if it fails returns the provided
   * default value. This is so that possibly validated, but non-valid inputs still are useful. For example,
   * a user may input a single minus sign in any text input, which is a valid value. If the user now confirms
   * the changes, a number format exception is raised and the default value will be used instead.
   *
   * @param value The value to parse.
   * @param defaultValue The default value to use when parsing fails.
   * @returns The parsed float value, if successfull. Otherwise the provided default value.
   */
  private float getValueOrDefault(String value, float defaultValue)
  {
    try
    {
      return Float.parseFloat(value);
    }
    catch (NumberFormatException ex)
    {
      return defaultValue;
    }
  }
  
  /**
   * Registers a text field on the given panel, with the provided y level, label, default value and its event handler.
   *
   * @param panel The panel to register the text field in.
   * @param y The y level of this text field.
   * @param label The target label text.
   * @param defaultValue The initial text of this text field.
   * @param eventHandlerName The name of the function to handle events for this input.
   */
  private void registerTextField(GPanel panel, int y, String label, String defaultValue, String eventHandlerName)
  {
    panel.addControl(new GLabel(BarrelShooter.this, 25, y, 125, 20, label));
    
    GTextField textField = new GTextField(BarrelShooter.this, 175, y, 100, 20, GTextField.SCROLLBARS_NONE);
    textField.setText(defaultValue);
    textField.addEventHandler(this, eventHandlerName);
    panel.addControl(textField);
  }
  
  /**
   * Registers a text field on the given panel with four different inputs,
   * with the provided y level, label, default value and its event handler.
   *
   * @param panel The panel to register the text field in.
   * @param y The y level of this text field.
   * @param label The target label text.
   * @param textFields The array in which to store all newly created text fields.
   * @param defaultValues An array of default values for each text field.
   * @param eventHandlerName The name of the function to handle events for these inputs.
   */
  private void registerVec4Input(GPanel panel, int y, String label, GTextField[] textFields, String[] defaultValues, String eventHandlerName)
  {
    panel.addControl(new GLabel(BarrelShooter.this, 25, y, 125, 20, label));
    for (int i = 0; i < 4; i++)
    {
      textFields[i] = new GTextField(BarrelShooter.this, 125 + 38 * i, y, 36, 20, GTextField.SCROLLBARS_NONE);
      textFields[i].setText(defaultValues[i]);
      textFields[i].addEventHandler(this, eventHandlerName);
      panel.addControl(textFields[i]);
    }
  }
  
  /**
   * Draws a basic image to the UI, given the image to draw, the x and y coordinates and the width/height
   * of the image.
   *
   * @param image The image to display.
   * @param x The top left x coordinate.
   * @param y The top left y coordinate.
   * @param width The targeted width.
   * @param height The targeted height.
   */
  private void drawUIImage(PImage image, float x, float y, float width, float height)
  {
    beginShape();
    texture(image);
    
    // Just a 3D quad width the given parameters.
    vertex(x, y, 0, 0);
    vertex(x + width, y, 1, 0);
    vertex(x + width, y + height, 1, 1);
    vertex(x, y + height, 0, 1);
    
    endShape();
  }
  
  /**
   * Resets the game if either forced or conditions are met. Will respawn all barrels
   * and reset the minigame UI values to their defaults according to the current settings.
   *
   * @param force Whether or not to force the reset or to match conditions.
   */
  private void resetGame(boolean force)
  {
    // We will have a minimum of 1 barrel.
    int targetBarrelCount = max(1, (int) getValueOrDefault(currentBarrelsAmountText, BARREL_AMOUNT_DEFAULT));
    if (!force && targetBarrelCount == barrelManager.getBarrelCount())
    {
      return;
    }
    
    barrelManager.clearBarrels();
    barrelManager.spawnBarrels(targetBarrelCount);
    
    shotsTotal = 2 * targetBarrelCount;
    shotsAvailable = shotsTotal;
    barrelsRemaining = targetBarrelCount;
  }
}
