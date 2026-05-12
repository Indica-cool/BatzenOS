package com.stoffplan.app.ui

import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import com.stoffplan.app.ui.screens.AddEditScreen
import com.stoffplan.app.ui.screens.DetailScreen
import com.stoffplan.app.ui.screens.HomeScreen
import com.stoffplan.app.ui.screens.SettingsScreen

object Routes {
    const val HOME = "home"
    const val ADD = "add"
    const val EDIT = "edit/{id}"
    const val DETAIL = "detail/{id}"
    const val SETTINGS = "settings"
    fun edit(id: Long) = "edit/$id"
    fun detail(id: Long) = "detail/$id"
}

@Composable
fun StoffPlanNavHost(nav: NavHostController) {
    val vm: EntryViewModel = viewModel(factory = EntryViewModel.Factory)

    NavHost(navController = nav, startDestination = Routes.HOME) {
        composable(Routes.HOME) {
            HomeScreen(
                vm = vm,
                onAdd = { nav.navigate(Routes.ADD) },
                onOpen = { id -> nav.navigate(Routes.detail(id)) },
                onSettings = { nav.navigate(Routes.SETTINGS) }
            )
        }
        composable(Routes.ADD) {
            AddEditScreen(vm = vm, entryId = null, onDone = { nav.popBackStack() })
        }
        composable(
            Routes.EDIT,
            arguments = listOf(navArgument("id") { type = NavType.LongType })
        ) { backStack ->
            val id = backStack.arguments?.getLong("id")
            AddEditScreen(vm = vm, entryId = id, onDone = { nav.popBackStack() })
        }
        composable(
            Routes.DETAIL,
            arguments = listOf(navArgument("id") { type = NavType.LongType })
        ) { backStack ->
            val id = backStack.arguments?.getLong("id") ?: return@composable
            DetailScreen(
                vm = vm,
                id = id,
                onEdit = { nav.navigate(Routes.edit(id)) },
                onBack = { nav.popBackStack() }
            )
        }
        composable(Routes.SETTINGS) {
            SettingsScreen(vm = vm, onBack = { nav.popBackStack() })
        }
    }
}
