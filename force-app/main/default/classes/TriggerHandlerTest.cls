/**
 * @description Test class for base TriggerHandler class
 * @author Kevin OHara (https://github.com/kevinohara80)
 * @since 2013
 * @author David Schach (https://github.com/dschach)
 * @since 2021 Update, add new methods
 * @since 2023-02-08 Update assert methods to Assert class
 * @group Trigger Handler
 * @see TriggerHandler
 */
@isTest
private class TriggerHandlerTest {
  private static String lastMethodCalled;
  private static TriggerHandlerTest.TestHandler handler;

  static {
    handler = new TriggerHandlerTest.TestHandler();
    // override its internal trigger detection
    handler.isTriggerExecuting = true;
  }

  // context tests

  @isTest
  private static void testBeforeInsert() {
    beforeInsertMode();
    handler.run();
    Assert.areEqual(
      'beforeInsert',
      lastMethodCalled,
      'last method should be beforeInsert'
    );
    Assert.areEqual(
      System.TriggerOperation.BEFORE_INSERT,
      handler.triggerEvent,
      'triggerEvent should be set to current context'
    );
  }

  @isTest
  private static void testBeforeUpdate() {
    beforeUpdateMode();
    handler.run();
    Assert.areEqual(
      'beforeUpdate',
      lastMethodCalled,
      'last method should be beforeUpdate'
    );
  }

  @isTest
  private static void testBeforeDelete() {
    beforeDeleteMode();
    handler.run();
    Assert.areEqual(
      'beforeDelete',
      lastMethodCalled,
      'last method should be beforeDelete'
    );
  }

  @isTest
  private static void testAfterInsert() {
    afterInsertMode();
    handler.run();
    Assert.areEqual(
      'afterInsert',
      lastMethodCalled,
      'last method should be afterInsert'
    );
  }

  @isTest
  private static void testAfterUpdate() {
    afterUpdateMode();
    handler.run();
    Assert.areEqual(
      'afterUpdate',
      lastMethodCalled,
      'last method should be afterUpdate'
    );
  }

  @isTest
  private static void testAfterDelete() {
    afterDeleteMode();
    handler.run();
    Assert.areEqual(
      'afterDelete',
      lastMethodCalled,
      'last method should be afterDelete'
    );
  }

  @isTest
  private static void testAfterUndelete() {
    afterUndeleteMode();
    handler.run();
    Assert.areEqual(
      'afterUndelete',
      lastMethodCalled,
      'last method should be afterUndelete'
    );
  }

  @isTest
  private static void testNonTriggerContext() {
    try {
      handler.run();
      Assert.isTrue(
        false,
        'the handler ran but should have thrown an exception'
      );
    } catch (TriggerHandler.TriggerHandlerException te) {
      Assert.areEqual(
        TriggerHandler.ERROR_TRIGGERCONTEXT,
        te.getMessage(),
        'the exception message should match'
      );
    } catch (Exception e) {
      Assert.isTrue(
        false,
        'the exception thrown was not expected: ' +
          e.getTypeName() +
          ': ' +
          e.getMessage()
      );
    }
  }

  @isTest
  private static void testConstructorWithParameter() {
    handler = new TriggerHandlerTest.TestHandler('TestHandler');
    // override its internal trigger detection
    handler.isTriggerExecuting = true;
    beforeInsertMode();
    handler.run();
    assertTestHandlerName();
    Assert.areEqual(
      'beforeInsert',
      lastMethodCalled,
      'last method should be beforeInsert'
    );
  }

  @isTest
  private static void testConstructorWithParametersAndBypass() {
    handler = new TriggerHandlerTest.TestHandler('TestHandler');
    // override its internal trigger detection
    handler.isTriggerExecuting = true;
    beforeUpdateMode();
    TriggerHandler.bypass('TestHandler');
    handler.run();
    Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
    Assert.isTrue(
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should be bypassed'
    );
    resetTest();
  }

  /**
   * @description test bypass api
   */
  @isTest
  private static void testBypassAPI() {
    afterUpdateMode();

    // test a bypass and run handler
    TriggerHandler.bypass('TestHandler');
    handler.run();
    Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
    Assert.isTrue(
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should be bypassed'
    );
    resetTest();

    // clear that bypass and run handler
    TriggerHandler.clearBypass('TestHandler');
    handler.run();
    Assert.areEqual(
      'afterUpdate',
      lastMethodCalled,
      'last method called should be afterUpdate'
    );
    Assert.isFalse(
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should not be bypassed'
    );
    resetTest();

    // test a bypass and run handler
    TriggerHandler.bypass('TestHandler');
    handler.run();
    Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
    Assert.isTrue(
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should be bypassed'
    );
    resetTest();

    // clear all bypasses and run handler
    TriggerHandler.clearBypass('TestHandler');
    handler.run();
    Assert.areEqual(
      'afterUpdate',
      lastMethodCalled,
      'last method called should be afterUpdate'
    );
    Assert.isFalse(
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should not be bypassed'
    );
    resetTest();
  }

  /**
   * @description instance method tests
   */
  @isTest
  private static void testLoopCount() {
    beforeInsertMode();

    // set the max loops to 2
    handler.setMaxLoopCount(2).run();
    handler.run();

    Assert.areEqual(
      2,
      TriggerHandler.getLoopCount('TestHandler'),
      'We should have run the handler only twice.'
    );

    assertTestHandlerName();

    // clear the tests
    resetTest();

    handler.run();
    Assert.isTrue(
      TriggerHandler.loopCountMap.get('TestHandler').getCount() >
      TriggerHandler.loopCountMap.get('TestHandler').getMax(),
      'We should have exceeded the max count'
    );

    // clear the tests
    resetTest();

    // now clear the loop count
    handler.clearMaxLoopCount();

    handler.run();
    Assert.areEqual(
      'beforeInsert',
      lastMethodCalled,
      'last method should be beforeInsert'
    );
  }

  @isTest
  private static void testLoopCountClass() {
    TriggerHandler.LoopCount lc = new TriggerHandler.LoopCount();
    Assert.areEqual(5, lc.getMax(), 'max should be five on init');
    Assert.areEqual(0, lc.getCount(), 'count should be zero on init');

    lc.increment();
    Assert.areEqual(1, lc.getCount(), 'count should be 1');
    Assert.isFalse(lc.exceeded(), 'should not be exceeded with count of 1');

    lc.increment();
    lc.increment();
    lc.increment();
    lc.increment();
    Assert.areEqual(5, lc.getCount(), 'count should be 5');
    Assert.isFalse(lc.exceeded(), 'should not be exceeded with count of 5');

    lc.increment();
    Assert.areEqual(6, lc.getCount(), 'count should be 6');
    Assert.isTrue(lc.exceeded(), 'should be exceeded with count of 6');
  }

  @isTest
  private static void testLoopCountWithMaxSet() {
    TriggerHandler.LoopCount lc = new TriggerHandler.LoopCount(3);
    Assert.areEqual(3, lc.getMax(), 'max should be three on init');
    Assert.areEqual(0, lc.getCount(), 'count should be zero on init');

    lc.increment();
    lc.increment();
    lc.increment();
    Assert.isFalse(lc.exceeded(), 'should not be exceeded with count of 3');

    lc.increment();
    Assert.isTrue(lc.exceeded(), 'should be exceeded with count of 4');

    lc.setMax(10);
    Assert.areEqual(10, lc.getMax(), 'max should be updated to 10');
    Assert.isFalse(
      lc.exceeded(),
      'should not be exceeded with count of 4 and max of 10'
    );
  }

  /**
   * @description Ensure that the current handler name is as expected
   */
  private static void assertTestHandlerName() {
    Assert.areEqual(
      'TestHandler',
      handler.getHandlerName(),
      'handler name should match class name'
    );
  }

  /**
   * @description test virtual methods
   */
  @isTest
  private static void testVirtualMethods() {
    TriggerHandler h = new TriggerHandler();
    h.beforeInsert();
    h.beforeUpdate();
    h.beforeDelete();
    h.afterInsert();
    h.afterUpdate();
    h.afterDelete();
    h.afterUndelete();
    h.andFinally();
    Assert.isTrue(true, 'Method is for code coverage only');
  }

  /**
   * @description call from outside trigger
   */
  @isTest
  private static void testOutsideTrigger() {
    TriggerHandler th = new TriggerHandler();
    Assert.isFalse(th.isTriggerExecuting, 'Should be outside trigger context');
    th.setTriggerContext(null, true);
    Assert.isFalse(th.isTriggerExecuting, 'Should be outside trigger context');
  }

  // testing utilities

  private static void resetTest() {
    lastMethodCalled = null;
  }

  // modes for testing

  private static void beforeInsertMode() {
    handler.setTriggerContext(System.TriggerOperation.BEFORE_INSERT, true);
  }

  private static void beforeUpdateMode() {
    handler.setTriggerContext(System.TriggerOperation.BEFORE_UPDATE, true);
  }

  private static void beforeDeleteMode() {
    handler.setTriggerContext(System.TriggerOperation.BEFORE_DELETE, true);
  }

  private static void afterInsertMode() {
    handler.setTriggerContext(System.TriggerOperation.AFTER_INSERT, true);
  }

  private static void afterUpdateMode() {
    handler.setTriggerContext(System.TriggerOperation.AFTER_UPDATE, true);
  }

  private static void afterDeleteMode() {
    handler.setTriggerContext(System.TriggerOperation.AFTER_DELETE, true);
  }

  private static void afterUndeleteMode() {
    handler.setTriggerContext(System.TriggerOperation.AFTER_UNDELETE, true);
  }

  /**
   * @description test implementation of the TriggerHandler
   */
  private class TestHandler extends TriggerHandler {
    /**
     * @description Invoke constructor
     */
    public TestHandler() {
      super('TestHandler');
    }

    /**
     * @description Override the trigger handler constructor that takes the handler name as a parameter
     * @param handlerName The handler name to instantiate
     */
    @SuppressWarnings('PMD.EmptyStatementBlock')
    public TestHandler(String handlerName) {
      // Empty constructor for testing
    }

    public override void beforeInsert() {
      TriggerHandlerTest.lastMethodCalled = 'beforeInsert';
    }

    public override void beforeUpdate() {
      TriggerHandlerTest.lastMethodCalled = 'beforeUpdate';
    }

    public override void beforeDelete() {
      TriggerHandlerTest.lastMethodCalled = 'beforeDelete';
    }

    public override void afterInsert() {
      TriggerHandlerTest.lastMethodCalled = 'afterInsert';
    }

    public override void afterUpdate() {
      TriggerHandlerTest.lastMethodCalled = 'afterUpdate';
    }

    public override void afterDelete() {
      TriggerHandlerTest.lastMethodCalled = 'afterDelete';
    }

    public override void afterUndelete() {
      TriggerHandlerTest.lastMethodCalled = 'afterUndelete';
    }
  }
}
