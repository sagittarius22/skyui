﻿import Shared.ListFilterer;
import skyui.IFilter;

class skyui.FilteredList extends skyui.DynamicScrollingList
{
	private var _filteredList:Array;
	private var _filterChain:Array;

	private var _curClipIndex:Number;
	private var _lastScrollPos:Number;
	private var _oldEntryClipIndex:Number;

	function FilteredList()
	{
		super();
		_filteredList = new Array();
		_filterChain = new Array();
		_curClipIndex = -1;
		_lastScrollPos = -1;
		_oldEntryClipIndex = -1;
	}

	function addFilter(a_filter:IFilter)
	{
		if (DEBUG_LEVEL > 0)
			_global.skse.Log("FilteredList addFilter()");		
		_filterChain.push(a_filter);
	}
	
	function getFilteredEntry(a_index:Number):Object
	{
		if (DEBUG_LEVEL > 0)
			_global.skse.Log("FilteredList getFilteredEntry()");
		return _filteredList[a_index];
	}

	// Did you mean: numFilteredItems() ?
	function get numUnfilteredItems():Number
	{
		return _filteredList.length;
	}

	function generateFilteredList()
	{
		if (DEBUG_LEVEL > 0)
			_global.skse.Log("FilteredList generateFilteredList()");
		_filteredList.splice(0);

		for (var i = 0; i < _entryList.length; i++) {
			_entryList[i].unfilteredIndex = i;
			_entryList[i].filteredIndex = undefined;
			_filteredList[i] = _entryList[i];
		}

		for (var i = 0; i < _filterChain.length; i++) {
			_filterChain[i].process(_filteredList);
		}

		for (var i = 0; i < _filteredList.length; i++) {
			_filteredList[i].filteredIndex = i;
		}

		if (selectedEntry.filteredIndex == undefined) {
			_selectedIndex = -1;
		}
	}

	function UpdateList()
	{
		if (DEBUG_LEVEL > 0)
			_global.skse.Log("<========================FilteredList UpdateList==================================" + "\n");
		var yStart = _indent;
		var h = 0;

		for (var i = 0; i < _filteredList.length && i < _scrollPosition; i++) {
			_filteredList[i].clipIndex = undefined;
		}

		_listIndex = 0;

		for (var i = _scrollPosition; i < _filteredList.length && _listIndex < _maxListIndex; i++) {
			var entryClip = getClipByIndex(_listIndex);
			if (DEBUG_LEVEL > 1)
				_global.skse.Log("FilteredList UpdateList() setEntry " + _filteredList[i].text + " unfilteredIndex = " + _filteredList[i].unfilteredIndex);
			setEntry(entryClip,_filteredList[i]);
			entryClip.itemIndex = _filteredList[i].unfilteredIndex;
			_filteredList[i].clipIndex = _listIndex;

			entryClip._y = yStart + h;
			entryClip._visible = true;

			h = h + _entryHeight;

			_listIndex++;
		}

		for (var i = _listIndex; i < _maxListIndex; i++) {
			getClipByIndex(i)._visible = false;
			getClipByIndex(i).itemIndex = undefined;
		}

		// Select entry under the cursor
		if (_bMouseDrivenNav) {
			for (var e = Mouse.getTopMostEntity(); e != undefined; e = e._parent) {
				if (e._parent == this && e._visible && e.itemIndex != undefined) {
					if (DEBUG_LEVEL > 1)
						_global.skse.Log("FilteredList UpdateList() doSetSelectedIndex " + e.itemIndex + " for entry " + e.text);
					doSetSelectedIndex(e.itemIndex,0);
				}
			}
		}
		_global.skse.Log("========================END FilteredList UpdateList==================================>" + "\n");
	}

	function InvalidateData()
	{
            	if (DEBUG_LEVEL > 0)
			_global.skse.Log("<========================FilteredList InvalidateData==================================" + "\n");
		generateFilteredList();
		super.InvalidateData();
		
		// Restore selection
		if (_curClipIndex != undefined && _curClipIndex != -1 && _listIndex > 0) {
			
			if (_curClipIndex >= _listIndex) {
				_curClipIndex = _listIndex - 1;
			}
			
			var entryClip = getClipByIndex(_curClipIndex);
			
			doSetSelectedIndex(entryClip.itemIndex, 1);
		}
		_global.skse.Log("========================END FilteredList InvalidateData==================================>" + "\n");
	}

	function calculateMaxScrollPosition()
	{
		if (DEBUG_LEVEL > 0)
			_global.skse.Log("FilteredList calculateMaxScrollPosition");
		var t = _filteredList.length - _maxListIndex;
		_maxScrollPosition = (t > 0) ? t : 0;

		if (_scrollPosition > _maxScrollPosition) {
			scrollPosition = _maxScrollPosition;
		}

		updateScrollbar();
	}

	function moveSelectionUp(a_bScrollPage:Boolean)
	{
		if (DEBUG_LEVEL > 0)
			_global.skse.Log("FilteredList moveSelectionUp()");
		if (!_bDisableSelection && !a_bScrollPage) {
			if (_selectedIndex == -1) {
				selectDefaultIndex(false);
			} else if (selectedEntry.filteredIndex > 0) {
				doSetSelectedIndex(_filteredList[selectedEntry.filteredIndex - 1].unfilteredIndex,1);
				_bMouseDrivenNav = false;
				dispatchEvent({type:"listMovedUp", index:_selectedIndex, scrollChanged:true});
			}
		} else if (a_bScrollPage) {
			var t = scrollPosition - _listIndex;
			scrollPosition = t > 0 ? t : 0;
			doSetSelectedIndex(-1, 0);
		} else {
			scrollPosition = scrollPosition - 1;
		}
	}

	function moveSelectionDown(a_bScrollPage:Boolean)
	{
		if (DEBUG_LEVEL > 0)
			_global.skse.Log("FilteredList moveSelectionDown()");
		if (!_bDisableSelection && !a_bScrollPage) {
			if (_selectedIndex == -1) {
				selectDefaultIndex(true);
			} else if (selectedEntry.filteredIndex < _filteredList.length - 1) {
				doSetSelectedIndex(_filteredList[selectedEntry.filteredIndex + 1].unfilteredIndex,1);
				_bMouseDrivenNav = false;
				dispatchEvent({type:"listMovedDown", index:_selectedIndex, scrollChanged:true});
			}
		} else if (a_bScrollPage) {
			var t = scrollPosition + _listIndex;
			scrollPosition = t < _maxScrollPosition ? t : _maxScrollPosition;
			doSetSelectedIndex(-1, 0);
		} else {
			scrollPosition = scrollPosition + 1;
		}
	}

	function doSetSelectedIndex(a_newIndex:Number, a_keyboardOrMouse:Number)
	{
		if (DEBUG_LEVEL > 0)
			_global.skse.Log("FilteredList doSetSelectedIndex()");
		if (DEBUG_LEVEL > 0)
			_global.skse.Log("FilteredList doSetSelectedIndex " + a_newIndex + " , selectedIndex = " + _selectedIndex + " , bDisableSelection = " + _bDisableSelection);
		// if new selected index is the same , ignore
		if (!_bDisableSelection && a_newIndex != _selectedIndex) {
			var oldIndex = _selectedIndex;
			_selectedIndex = a_newIndex;
			var newEntry = _entryList[_selectedIndex];
			var clipDiff = (_maxListIndex - _oldEntryClipIndex);
			if (DEBUG_LEVEL > 1)
				_global.skse.Log("clipDiff = " + clipDiff + "oldClipIndex = " + _oldEntryClipIndex + " , _maxListIndex = " + _maxListIndex + ", lastScrollPos = " + _lastScrollPos + ", scrollPosition = " + _scrollPosition);
			/*
				Since vanilla does not use a scrollbar, we must verify if the old entry is still visible 
				on list when we scroll up or down. If we highlight a new item and the old item is not
				visible, the item will try to set itself over a new entry at it's old clipIndex. This bug
				fix prevents this from happening by doing the following checks :
				
				1. If scroll position has changed and is not the same as our previous then continue.
				2. If last scroll position is > than new scroll position then we have moved up so continue
				to step 3 else continue to 4.
				// moved up
				3. If the difference of last scroll and new scroll position is greater than our allowed
				movement, do not update old entry since it is no longer visible.
				// moved down
				4. If the difference of new scroll and last scroll position is greater than our old
				clip index, do not update old entry since it is no longer visible.
			*/
			if (_lastScrollPosition != _scrollPosition && _lastScrollPos != -1) {
				if (_lastScrollPosition > _scrollPosition) { // moved scrollbar up
					// check scroll pos
					if ((_lastScrollPosition - _scrollPosition) > clipDiff) {
						oldIndex = -1;
					}
				} else { // moved scrollbar down 
					if ((_scrollPosition - _lastScrollPos) > _oldEntryClipIndex) {
						oldIndex = -1
					}
				}
			}
			
			if (oldIndex != -1) {
				if (DEBUG_LEVEL > 0) _global.skse.Log("doSetSelectedIndex setting old entry " + _entryList[oldIndex].text + " at clipIndex " + _entryList[oldIndex].clipIndex);
				setEntry(getClipByIndex(_entryList[oldIndex].clipIndex),_entryList[oldIndex]);
			}

			if (_selectedIndex != -1) {
				// save our current entry clip index for next selection 
				_oldEntryClipIndex = newEntry.clipIndex;
				if (selectedEntry.filteredIndex < _scrollPosition) {
					scrollPosition = selectedEntry.filteredIndex;
				} else if (selectedEntry.filteredIndex >= _scrollPosition + _listIndex) {
					scrollPosition = Math.min(selectedEntry.filteredIndex - _listIndex + 1, _maxScrollPosition);
				} else {
					if (DEBUG_LEVEL > 0)
						_global.skse.Log("doSelectedIndex setting entry " + _entryList[_selectedIndex].text);
					setEntry(getClipByIndex(_entryList[_selectedIndex].clipIndex),_entryList[_selectedIndex]);
				}
				
				_curClipIndex = _entryList[_selectedIndex].clipIndex;
			} else {
				_curClipIndex = -1;
			}
			// save our current scroll position for next selection
			_lastScrollPos = _scrollPosition;
			dispatchEvent({type:"selectionChange", index:_selectedIndex, keyboardOrMouse:a_keyboardOrMouse});
		}
	}

	function onFilterChange()
	{
		if (DEBUG_LEVEL > 0)
			_global.skse.Log("FilteredList onFilterChange()");
		generateFilteredList();
		calculateMaxScrollPosition();
		UpdateList();
	}
}