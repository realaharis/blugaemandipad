package com.blugaemand.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.blugaemand.hid.*
import kotlinx.coroutines.delay

@Composable
fun Ds4Touchpad(output: Ds4Output, onChange: (Ds4Touch) -> Unit, modifier: Modifier = Modifier) {
    var touch by remember { mutableStateOf(Ds4Touch()) }
    val callback by rememberUpdatedState(onChange)
    var illuminated by remember { mutableStateOf(true) }
    LaunchedEffect(output.flashOn, output.flashOff) {
        illuminated = true
        if (output.flashOn > 0 && output.flashOff > 0) while (true) {
            illuminated = true; delay(output.flashOn * 10L)
            illuminated = false; delay(output.flashOff * 10L)
        }
    }
    Column(modifier) {
        Box(Modifier.fillMaxWidth().height(4.dp).background(if (illuminated)
            Color(output.red, output.green, output.blue) else Color.Black))
        Box(Modifier.fillMaxWidth().height(76.dp).background(Color(0xFF202632)).pointerInput(Unit) {
            try {
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent()
                        val contacts = event.changes.filter { it.pressed }.take(2).map {
                            Ds4Contact(it.id.value.toInt() and 127,
                                (it.position.x / size.width.coerceAtLeast(1) * 1919).toInt(),
                                (it.position.y / size.height.coerceAtLeast(1) * 941).toInt())
                        }
                        touch = touch.copy(first = contacts.getOrNull(0), second = contacts.getOrNull(1))
                        callback(touch)
                        event.changes.forEach { it.consume() }
                    }
                }
            } finally { touch = Ds4Touch(); callback(touch) }
        }, contentAlignment = Alignment.Center) {
            Text("DS4 touchpad", color = Color.White, fontSize = 11.sp)
        }
        Box(Modifier.fillMaxWidth().padding(top = 3.dp).height(30.dp).background(Color(0xFF303948)).pointerInput(Unit) {
            try {
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent()
                        touch = touch.copy(clicked = event.changes.any { it.pressed })
                        callback(touch)
                        event.changes.forEach { it.consume() }
                    }
                }
            } finally { touch = touch.copy(clicked = false); callback(touch) }
        }, contentAlignment = Alignment.Center) {
            Text("Touchpad click", color = Color.White, fontSize = 10.sp)
        }
    }
}
