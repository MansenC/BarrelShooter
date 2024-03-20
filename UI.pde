import java.util.function.Consumer;
import g4p_controls.*;

public static final int BARREL_AMOUNT_DEFAULT = 10;
public static final float BARREL_WEIGHT_DEFAULT = 2000f;
public static final float CANNONBALL_WEIGHT_DEFAULT = 200f;
public static final float CANNONBALL_FORCE_DEFAULT = 280_000f;

public static final float WAVE_SPEED_DEFAULT = 0.05f;
public static final float WAVE_SCALE_DEFAULT = 0.2f;
public static final float[] WAVE_AMPLITUDES_DEFAULT = new float[] { 0.1f, 0.05f, 0.05f, 0.025f };
public static final float[] WAVE_FREQUENCIES_DEFAULT = new float[] { 1.0f / 2.0f, 1.0f / 4.0f, 1.0f / 8.0f, 1.0f / 10.0f };

public class UI
{
  private final GGroup uiGroup;
  private final GButton gameUpdate;
  private final GButton oceanUpdate;
  
  private String currentBarrelsAmountText = Integer.toString(BARREL_AMOUNT_DEFAULT);
  private String currentBarrelWeightText = Float.toString(BARREL_WEIGHT_DEFAULT);
  private String currentCannonballWeightText = Float.toString(CANNONBALL_WEIGHT_DEFAULT);
  private String currentCannonForceText = Float.toString(CANNONBALL_FORCE_DEFAULT);
  
  private String currentWaveSpeedText = Float.toString(WAVE_SPEED_DEFAULT);
  private String currentWaveScaleText = Float.toString(WAVE_SCALE_DEFAULT);
  
  private final GTextField[] waveAmplitudes = new GTextField[4];
  private String[] currentWaveAmplitudesTexts = new String[]
  {
    Float.toString(WAVE_AMPLITUDES_DEFAULT[0]),
    Float.toString(WAVE_AMPLITUDES_DEFAULT[1]),
    Float.toString(WAVE_AMPLITUDES_DEFAULT[2]),
    Float.toString(WAVE_AMPLITUDES_DEFAULT[3])
  };
  
  private final GTextField[] waveFrequencies = new GTextField[4];
  private String[] currentWaveFrequenciesTexts = new String[]
  {
    Float.toString(WAVE_FREQUENCIES_DEFAULT[0]),
    Float.toString(WAVE_FREQUENCIES_DEFAULT[1]),
    Float.toString(WAVE_FREQUENCIES_DEFAULT[2]),
    Float.toString(WAVE_FREQUENCIES_DEFAULT[3])
  };
  
  private boolean visible = false;
  
  public UI()
  {
    G4P.messagesEnabled(false);
    
    uiGroup = new GGroup(BarrelShooter.this, 0);
    
    GPanel gamePanel = new GPanel(BarrelShooter.this, 100, 100, 300, 180, "Game Settings");
    
    registerTextField(gamePanel, 30, "Barrels", currentBarrelsAmountText, "handleBarrelsAmountUpdate");
    registerTextField(gamePanel, 60, "Barrel Weight", currentBarrelWeightText, "handleBarrelWeightUpdate");
    registerTextField(gamePanel, 90, "Cannonball Weight", currentCannonballWeightText, "handleCannonballWeightUpdate");
    registerTextField(gamePanel, 120, "Cannon Force", currentCannonForceText, "handleCannonForceUpdate");
    
    gameUpdate = new GButton(BarrelShooter.this, 225, 150, 50, 20, "Update");
    gameUpdate.addEventHandler(this, "handleGameSettingsUpdateRequested");
    gamePanel.addControl(gameUpdate);
    
    uiGroup.addControl(gamePanel);
    
    GPanel oceanPanel = new GPanel(BarrelShooter.this, 500, 100, 300, 180, "Ocean Settings");
    
    registerTextField(oceanPanel, 30, "Wave Speed", currentWaveSpeedText, "handleWaveSpeedUpdate");
    registerTextField(oceanPanel, 60, "Wave Scale", currentWaveScaleText, "handleWaveScaleUpdate");
    registerVec4Input(oceanPanel, 90, "Amplitudes", waveAmplitudes, currentWaveAmplitudesTexts, "handleWaveAmplitudesUpdate");
    registerVec4Input(oceanPanel, 120, "Frequencies", waveFrequencies, currentWaveFrequenciesTexts, "handleWaveFrequenciesUpdate");
    
    oceanUpdate = new GButton(BarrelShooter.this, 225, 150, 50, 20, "Update");
    oceanUpdate.addEventHandler(this, "handleOceanSettingsUpdateRequested");
    oceanPanel.addControl(oceanUpdate);
    
    uiGroup.addControl(oceanPanel);
  }
  
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
  
  public boolean isVisible()
  {
    return visible;
  }
  
  public void handleGameSettingsUpdateRequested(@SuppressWarnings("unused") GButton button, GEvent event)
  {
    if (event != GEvent.CLICKED)
    {
      return;
    }
    
    barrelManager.setBarrelWeight(getValueOrDefault(currentBarrelWeightText, BARREL_WEIGHT_DEFAULT));
    cannonballForce = getValueOrDefault(currentCannonForceText, CANNONBALL_FORCE_DEFAULT);
    cannonballWeight = getValueOrDefault(currentCannonballWeightText, CANNONBALL_WEIGHT_DEFAULT);
    
    int targetBarrelCount = (int) getValueOrDefault(currentBarrelsAmountText, BARREL_AMOUNT_DEFAULT);
    if (targetBarrelCount == barrelManager.getBarrelCount())
    {
      return;
    }
    
    barrelManager.clearBarrels();
    barrelManager.spawnBarrels(targetBarrelCount);
  }
  
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
  
  public void handleBarrelWeightUpdate(GTextField input, GEvent event)
  {
    handleFloatInputUpdate(input, event, currentBarrelWeightText, text -> currentBarrelWeightText = text);
  }
  
  public void handleCannonballWeightUpdate(GTextField input, GEvent event)
  {
    handleFloatInputUpdate(input, event, currentCannonballWeightText, text -> currentCannonballWeightText = text);
  }
  
  public void handleCannonForceUpdate(GTextField input, GEvent event)
  {
    handleFloatInputUpdate(input, event, currentCannonForceText, text -> currentCannonForceText = text);
  }
  
  public void handleWaveSpeedUpdate(GTextField input, GEvent event)
  {
    handleFloatInputUpdate(input, event, currentWaveSpeedText, text -> currentWaveSpeedText = text);
  }
  
  public void handleWaveScaleUpdate(GTextField input, GEvent event)
  {
    handleFloatInputUpdate(input, event, currentWaveScaleText, text -> currentWaveScaleText = text);
  }
  
  public void handleWaveAmplitudesUpdate(GTextField input, GEvent event)
  {
    handleVec4FloatInputUpdate(input, event, waveAmplitudes, currentWaveAmplitudesTexts);
  }
  
  public void handleWaveFrequenciesUpdate(GTextField input, GEvent event)
  {
    handleVec4FloatInputUpdate(input, event, waveFrequencies, currentWaveFrequenciesTexts);
  }
  
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
  
  private void registerTextField(GPanel panel, int y, String label, String defaultValue, String eventHandlerName)
  {
    panel.addControl(new GLabel(BarrelShooter.this, 25, y, 125, 20, label));
    
    GTextField textField = new GTextField(BarrelShooter.this, 175, y, 100, 20, GTextField.SCROLLBARS_NONE);
    textField.setText(defaultValue);
    textField.addEventHandler(this, eventHandlerName);
    panel.addControl(textField);
  }
  
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
}
