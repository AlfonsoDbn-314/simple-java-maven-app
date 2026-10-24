package com.mycompany.app;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit test for simple App.
 */
class AppTest
{

    private final ByteArrayOutputStream outContent = new ByteArrayOutputStream();
    private final PrintStream originalOut = System.out;

    @BeforeEach
    void setUpStreams() {
        System.setOut(new PrintStream(outContent));
    }

    @Test
    void testAppConstructor() {
        assertDoesNotThrow(App::new, "Construction failed.");
    }

    @Test
    void testAppMain()
    {
        App.main(null);
        assertEquals("Hello World!" + System.lineSeparator(), outContent.toString(),
                "\"message\" is not \"Hello World!\"");
    }

    @AfterEach
    void cleanUpStreams() {
        System.setOut(originalOut);
    }

}
