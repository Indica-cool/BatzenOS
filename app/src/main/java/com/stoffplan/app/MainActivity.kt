package com.stoffplan.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.compose.rememberNavController
import com.stoffplan.app.ui.StoffPlanNavHost
import com.stoffplan.app.ui.theme.StoffPlanTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { App() }
    }
}

@Composable
private fun App() {
    StoffPlanTheme {
        Surface(modifier = Modifier.fillMaxSize()) {
            val nav = rememberNavController()
            StoffPlanNavHost(nav)
        }
    }
}
