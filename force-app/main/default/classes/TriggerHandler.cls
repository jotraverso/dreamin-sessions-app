@SuppressWarnings(
  'PMD.ExcessivePublicCount, PMD.CyclomaticComplexity, PMD.FieldDeclarationsShouldBeAtStart, PMD.EmptyStatementBlock'
)
/**
 * @description Trigger Handler virtual class as base for all trigger handlers
 * @author Kevin OHara (https://github.com/kevinohara80)
 * @since 2013
 * @author David Schach (https://github.com/dschach)
 * @since 2021
 * @since 2023-02-24 add andFinally method
 * @since 2023-09 method chaining
 * @group Trigger Handler
 * @see https://github.com/dschach/salesforce-trigger-framework
 */
public virtual class TriggerHandler {
  /**
   * Map of `handlerName` => times `run()` was invoked
   */
  @TestVisible
  private static Map<String, LoopCount> loopCountMap;

  /**
   * All bypassed handlers
   */
  @TestVisible
  private static Set<String> bypassedHandlers;

  /**
   * `true` if we bypass all triggers without checking the contents of `bypassedHandlers`
   */
  @TestVisible
  private static Boolean globalBypass;

  /**
   * `true` if we include a debug statement for limits
   */
  @TestVisible
  private static Boolean showLimits;

  /**
   * `true` if we include a debug statement for trigger entry and exit
   */
  @TestVisible
  private static Boolean showDebug;

  /**
   * The current triggerEvent of the trigger, overridable in tests
   */
  @TestVisible
  private System.TriggerOperation triggerEvent;

  /**
   * Is this class executing in trigger context?
   */
  @TestVisible
  private Boolean isTriggerExecuting;

  /**
   * This is the value that will be in the returned list or set when global bypass is active
   */
  @TestVisible
  private static final String BYPASS_ALL_ALIAS = 'BypassAll';

  /**
   * Error text - assumes English for debug logs
   */
  @TestVisible
  private static final String ERROR_TRIGGERCONTEXT = 'Trigger handler called outside of Trigger execution';

  // static initialization variables
  static {
    loopCountMap = new Map<String, LoopCount>();
    bypassedHandlers = new Set<String>();
    globalBypass = false;
    showLimits = false;
    showDebug = false;
  }

  /**
   * @description Basic constructor. Slower than the other one
   */
  public TriggerHandler() {
    this.setTriggerContext();
  }

  /**
   * @description Constructor with handler name to improve performance
   * @param handlerName The name of the handler
   */
  public TriggerHandler(String handlerName) {
    this.handlerName = handlerName;
    this.setTriggerContext();
  }

  /**
   * @description Main method that will be called during execution
   */
  public void run() {
    if (!validateRun()) {
      return;
    }

    if (!incrementCheckLoopCount()) {
      return;
    }

    if (showDebug) {
      System.debug(
        LoggingLevel.DEBUG,
        String.format(
          'Entering {0}, fired {1}',
          new List<String>{ getHandlerName(), this.triggerEvent + '' }
        )
      );
    }

    // dispatch to the correct handler method
    if (this.triggerEvent == System.TriggerOperation.BEFORE_INSERT) {
      this.beforeInsert();
    } else if (this.triggerEvent == System.TriggerOperation.BEFORE_UPDATE) {
      this.beforeUpdate();
    } else if (this.triggerEvent == System.TriggerOperation.BEFORE_DELETE) {
      this.beforeDelete();
    } else if (this.triggerEvent == System.TriggerOperation.AFTER_INSERT) {
      this.afterInsert();
    } else if (this.triggerEvent == System.TriggerOperation.AFTER_UPDATE) {
      this.afterUpdate();
    } else if (this.triggerEvent == System.TriggerOperation.AFTER_DELETE) {
      this.afterDelete();
    } else if (this.triggerEvent == System.TriggerOperation.AFTER_UNDELETE) {
      this.afterUndelete();
    }
    this.andFinally();

    if (showLimits) {
      System.debug(
        LoggingLevel.DEBUG,
        String.format(
          '{0} on {1} ({2}/{3} queries) and ({4}/{5} DML calls)',
          new List<String>{
            this.triggerEvent + '',
            getHandlerName(),
            Limits.getQueries() + '',
            Limits.getLimitQueries() + '',
            Limits.getDmlStatements() + '',
            Limits.getLimitDmlStatements() + ''
          }
        )
      );
    }
    if (showDebug) {
      System.debug(
        LoggingLevel.DEBUG,
        String.format(
          'Exiting {0}, fired {1}',
          new List<String>{ getHandlerName(), this.triggerEvent + '' }
        )
      );
    }
  }

  /**
   * @description Bypass a specific handler by name
   */
  public static void bypass(String handlerName) {
    TriggerHandler.bypassedHandlers.add(handlerName);
  }

  /**
   * @description Clear bypass for a specific handler
   */
  public static void clearBypass(String handlerName) {
    if (TriggerHandler.bypassedHandlers.contains(handlerName)) {
      TriggerHandler.bypassedHandlers.remove(handlerName);
    }
  }

  /**
   * @description Check if a handler is bypassed
   */
  public static Boolean isBypassed(String handlerName) {
    return (globalBypass ||
    TriggerHandler.bypassedHandlers.contains(handlerName));
  }

  /**
   * @description Set the max loop count for this handler
   * @param max Maximum number of times the handler can run
   * @return TriggerHandler instance for method chaining
   */
  public TriggerHandler setMaxLoopCount(Integer max) {
    String handlerName = getHandlerName();
    if (!TriggerHandler.loopCountMap.containsKey(handlerName)) {
      TriggerHandler.loopCountMap.put(handlerName, new LoopCount(max));
    } else {
      TriggerHandler.loopCountMap.get(handlerName).setMax(max);
    }
    return this;
  }

  /**
   * @description Clear the max loop count for this handler
   */
  public void clearMaxLoopCount() {
    this.setMaxLoopCount(-1);
  }

  /**
   * @description Get the current loop count for a handler
   * @param handlerName The handler name
   * @return Integer current loop count
   */
  public static Integer getLoopCount(String handlerName) {
    if (TriggerHandler.loopCountMap.containsKey(handlerName)) {
      return TriggerHandler.loopCountMap.get(handlerName).getCount();
    }
    return 0;
  }

  /**
   * @description Set the current trigger context
   */
  @TestVisible
  private void setTriggerContext() {
    this.setTriggerContext(Trigger.operationType, false);
  }

  /**
   * @description Set the trigger context based on operation type
   */
  @TestVisible
  private void setTriggerContext(
    System.TriggerOperation opType,
    Boolean testMode
  ) {
    if (!Trigger.isExecuting && !testMode) {
      this.isTriggerExecuting = false;
      return;
    } else {
      this.isTriggerExecuting = true;
    }

    if (Trigger.isExecuting && !testMode) {
      this.triggerEvent = Trigger.operationType;
    }

    String context = opType != null ? opType.name() : null;

    if (context == 'BEFORE_INSERT') {
      this.triggerEvent = System.TriggerOperation.BEFORE_INSERT;
    } else if (context == 'BEFORE_UPDATE') {
      this.triggerEvent = System.TriggerOperation.BEFORE_UPDATE;
    } else if (context == 'BEFORE_DELETE') {
      this.triggerEvent = System.TriggerOperation.BEFORE_DELETE;
    } else if (context == 'AFTER_INSERT') {
      this.triggerEvent = System.TriggerOperation.AFTER_INSERT;
    } else if (context == 'AFTER_UPDATE') {
      this.triggerEvent = System.TriggerOperation.AFTER_UPDATE;
    } else if (context == 'AFTER_DELETE') {
      this.triggerEvent = System.TriggerOperation.AFTER_DELETE;
    } else if (context == 'AFTER_UNDELETE') {
      this.triggerEvent = System.TriggerOperation.AFTER_UNDELETE;
    } else {
      this.isTriggerExecuting = false;
    }
  }

  /**
   * @description Increment the loop count and check if exceeded
   */
  private Boolean incrementCheckLoopCount() {
    String handlerName = getHandlerName();
    if (TriggerHandler.loopCountMap.containsKey(handlerName)) {
      Boolean exceeded = TriggerHandler.loopCountMap.get(handlerName)
        .increment();
      if (exceeded) {
        if (showDebug) {
          Integer max = TriggerHandler.loopCountMap.get(handlerName).max;
          System.debug(
            LoggingLevel.INFO,
            'Maximum loop count of ' +
              String.valueOf(max) +
              ' reached in ' +
              handlerName
          );
        }
        return false;
      }
      return true;
    }
    return true;
  }

  /**
   * @description Validate that the trigger should run
   */
  @TestVisible
  private Boolean validateRun() {
    if (!this.isTriggerExecuting || this.triggerEvent == null) {
      throw new TriggerHandlerException(ERROR_TRIGGERCONTEXT);
    }
    return (!globalBypass &&
    !TriggerHandler.bypassedHandlers.contains(getHandlerName()));
  }

  /**
   * @description The name of this handler
   */
  private String handlerName;

  /**
   * @description Get the name of the current handler
   */
  @TestVisible
  private String getHandlerName() {
    if (String.isBlank(this.handlerName)) {
      this.handlerName = this.toString().substringBefore(':');
    }
    return this.handlerName;
  }

  //trigger context methods - override these in your handler

  /**
   * @description Virtual method for the implementing class to override
   */
  @TestVisible
  protected virtual void beforeInsert() {
  }

  /**
   * @description Virtual method for the implementing class to override
   */
  @TestVisible
  protected virtual void beforeUpdate() {
  }

  /**
   * @description Virtual method for the implementing class to override
   */
  @TestVisible
  protected virtual void beforeDelete() {
  }

  /**
   * @description Virtual method for the implementing class to override
   */
  @TestVisible
  protected virtual void afterInsert() {
  }

  /**
   * @description Virtual method for the implementing class to override
   */
  @TestVisible
  protected virtual void afterUpdate() {
  }

  /**
   * @description Virtual method for the implementing class to override
   */
  @TestVisible
  protected virtual void afterDelete() {
  }

  /**
   * @description Virtual method for the implementing class to override
   */
  @TestVisible
  protected virtual void afterUndelete() {
  }

  /**
   * @description andFinally is called in every context, regardless of Trigger context
   */
  @TestVisible
  protected virtual void andFinally() {
  }

  /**
   * @description Inner class for managing the loop count per handler
   */
  @TestVisible
  private class LoopCount {
    private Integer max;
    private Integer count;

    public LoopCount() {
      this.max = 5;
      this.count = 0;
    }

    public LoopCount(Integer max) {
      this.max = max;
      this.count = 0;
    }

    public Boolean increment() {
      this.count++;
      return this.exceeded();
    }

    public Boolean exceeded() {
      return this.max >= 0 && this.count > this.max;
    }

    public Integer getMax() {
      return this.max;
    }

    public Integer getCount() {
      return this.count;
    }

    public void setMax(Integer max) {
      this.max = max;
    }
  }

  /**
   * @description Exception class
   */
  public class TriggerHandlerException extends Exception {
  }
}
