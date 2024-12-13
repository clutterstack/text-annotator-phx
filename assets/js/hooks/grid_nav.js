export const GridNav = {
  // this.el is the whole grid; the element with id annotated-content.
  // this JS hook handles interactions with that grid when there's no
  // editor component open in it.

  mounted() {

    this.config = {};

    this.resetConfig();

    console.log("maxRow: "+ this.config.maxRow + "; maxCol: " + this.config.maxCol);

    // Bind event handlers
    this.handleKeyUp = this.handleKeyUp.bind(this);
    this.handleMouseDown = this.handleMouseDown.bind(this);
    this.handleMouseOver = this.handleMouseOver.bind(this);
    this.handleMouseUp = this.handleMouseUp.bind(this);

    this.el.addEventListener('keyup', this.handleKeyUp);
    this.el.addEventListener('mousedown', this.handleMouseDown);
    this.el.addEventListener('mouseup', this.handleMouseUp);
  },

  updated() {
    console.log("DOM refreshed by LiveView")
    // this.resetConfig();
  },

  resetConfig() {
    console.log("before resetConfig(). this.config.lineCount = " + this.config.lineCount)
    this.config = {
      mode: this.el.dataset.mode,
      lineCount: this.el.querySelectorAll('[data-line-number]').length,
      maxRow: this.el.querySelectorAll('[role="row"]').length - 2, // minus one because header row doesn't count, minus another because zero-indexed (TODO: make rows start at 1)
      maxCol: this.el.querySelectorAll('[role="columnheader"]').length - 1
    }

    this.state = {
      isLineSelecting: false,
      firstSelectedLine: null,
      currentLine: null
    }

  },


  getCellAt(rowIndex, colIndex) {
    const element = document.querySelector(`[data-col-index="${colIndex}"][data-row-index="${rowIndex}"]`);
    if (element) {
        return element;
    } else {
        console.warn(`Element with data-col-index=${colIndex} and data-row-index=${rowIndex} not found.`);
    }
    return;
  },

  isEditing() {
    return this.el.querySelector('textarea') !== null;
  },

  startEdit(row, col) {
    // console.log("this.startEdit invoked with " + row + ", " + col)
    this.pushEvent("start_edit", {
      row_index: row,
      col_index: col
    });
    return
  },

  focusCell(row, col) {
    // console.log("this.focusCell: row, col: " + row + ", " + col)    
    const targetCell = this.getCellAt(row, col);
    if (targetCell) targetCell.focus();
  },

  handleArrowNav(key) {
    const directions = {
      ArrowUp: [-1, 0],
      ArrowDown: [1, 0],
      ArrowLeft: [0, -1],
      ArrowRight: [0, 1]
    };

    if (!directions[key]) return;
    const cellRow = Number(document.activeElement.dataset.rowIndex);
    const cellCol = Number(document.activeElement.dataset.colIndex);
    // console.log("[cellRow, cellCol]: " + [cellRow, cellCol])    
    const [rowDelta, colDelta] = directions[key];
    const newRow = Math.max(0, Math.min(this.config.maxRow, cellRow + rowDelta));
    const newCol = Math.max(0, Math.min(this.config.maxCol, cellCol + colDelta));
    console.log("Arrow to " + newRow + ", " + newCol);
    this.focusCell(newRow, newCol);
  },

  selectionMode(lineNumber) {
    // Enter selecting mode; don't start a selection
    console.log("selectionMode called with lineNumber " + lineNumber + " of type " + typeof(lineNumber))
    this.state.isLineSelecting = true;
  },

  selectionStart(lineNumber) {

    this.state.firstSelectedLine = lineNumber;
    console.log("selectionStart changed this.state.firstSelectedLine to " + this.state.firstSelectedLine + " with type " + typeof(this.state.firstSelectedLine));

    this.pushEvent('start_selection', {
      start: lineNumber,
      end: lineNumber
    });
  },
    
  selectionUpdate(start, end) {
    this.pushEvent('update_selection', { start, end });
  },

  selectionClear() {
    // console.log("selectionClear invoked; setting isLineSelecting to false")
    this.state.isLineSelecting = false;
    this.state.firstSelectedLine = null;
    this.state.currentLine = null;
    
    document.querySelectorAll('.selectedline')
      .forEach(el => el.classList.remove('selectedline'));
    
    this.pushEvent('cancel_selection', {});
  },

  submitChunk() {
    console.log("submitChunk: pushing rechunk event")
    this.pushEvent("rechunk");
    this.resetConfig();

  },

  handleChunkSelection(key) {
    lineNumStr = document.activeElement.dataset.lineNumber;
    if (!lineNumStr) {
      console.log("handleChunkSelection couldn't get a line number from the element")
      return;
    }
    lineNum = Number(lineNumStr);
    console.log("lineNum in handleChunkSelection is " + lineNum)
    if (key === ' ') {
      console.log("space key in chunkSelection")
      if (this.state.firstSelectedLine == null) {
        // Start new selection
        this.selectionStart(lineNum);
      } else {
        console.log("firstSelectedLine is not null so don't do anything")
      }
      return;
    } else if (!['ArrowUp', 'ArrowDown'].includes(key)) {
        return;
    }
    // At this point, key must be arrow up or down
    // If selection is started, don't need arrow keys to move without selecting
    console.log("*** Arrow keys in chunk selection mode ***");
    // console.log("this.state.firstSelectedLine is " + this.state.firstSelectedLine);
    const nextLine = key === 'ArrowUp' ? Math.max(lineNum - 1, this.state.firstSelectedLine) : Math.min(lineNum + 1, this.config.lineCount - 1);
    console.log("nextLine is " + nextLine)
    const nextEl = document.querySelector(`[data-line-number="${nextLine}"]`);

if (nextEl) {
  nextEl.focus();
} else {
  console.error('Element not found for data-line-number:', nextLine);
}
    // console.log("nextEl classlist: " + nextEl.classList);
    console.log("nextEl.dataset.lineNumber: " + nextEl.dataset.lineNumber + " of type " + typeof(nextEl.dataset.lineNumber));
    nextEl.focus();
    nextEl.classList.add("selectedline");
    console.log("nextEl: " + nextEl);

    if (this.state.firstSelectedLine !== null) {
      console.log("Updating selection by arrow keys. this.state.firstSelectedLine is " + this.state.firstSelectedLine + ", type " + typeof(this.state.firstSelectedLine) + " and last line selected is " + nextLine + ", type " + typeof(nextLine))

      this.selectionUpdate(this.state.firstSelectedLine, nextLine);
    }
  },

  // Event handlers
  handleKeyUp(e) {
    // console.log("handleKeyUp triggered with key " + e.key)
    if (this.isEditing()) return;
    
    e.preventDefault();

    const handlers = {
      Escape: () => this.handleEscape(),
      Enter: () => this.handleEnter(),
      default: () => {
        if (this.state.isLineSelecting) {
          this.handleChunkSelection(e.key, e.shiftKey);
        } else {
          this.handleArrowNav(e.key);
        }
      }
    };

    (handlers[e.key] || handlers.default)();
  },

  handleMouseDown(e) {
    const lineNumberEl = e.target.closest('.line-number');
    if (this.state.isLineSelecting && lineNumberEl == null) {
      console.log("got a mousedown outside of a line-number element");
      this.selectionClear();
      return;
    } 
    else if (lineNumberEl !== null) {
      e.preventDefault();
      const lineNumber = Number(lineNumberEl.innerText);
      console.log("mousedown at " + lineNumber);
      lineNumberEl.focus();
      this.selectionMode(lineNumber);
      this.selectionStart(lineNumber);
      this.state.currentLine = lineNumber;

      this.el.addEventListener('mouseover', this.handleMouseOver);
    };
  },

  handleMouseOver(e) {
    const lineNumberEl = e.target.closest('.line-number');
    if (!lineNumberEl) return;

    e.preventDefault();
    console.log("handleMouseOver");
    // console.log("mouseover at " + e.target.closest(".line-number").innerText);
    // linenumber.classList.remove("selectedline"); // in case I'm duplicating this class
    const thisLine = Number(lineNumberEl.innerText);
    const linediff = thisLine - this.state.currentLine;
    console.log("linediff: " + linediff );
    if (linediff > 0) {
      console.log("linediff is " + linediff + ". Adding class selectedline.")
      lineNumberEl.classList.add("selectedline");
    } else if (linediff < 0) {
      console.log("linediff is " + linediff + ". Removing class selectedline.")
      lineNumberEl.classList.remove("selectedline");
    }
    this.state.currentLine = thisLine;

    console.log("mouseover at " + thisLine + ". this.state.currentLine updated to " + this.state.currentLine + " with type " + typeof(this.state.currentLine))
  },

  handleMouseUp(e) {
    console.log("mouseup");
    if (!e.target.closest(".line-number")) {
      console.log("got a mouseup outside of a line-number element");
      // this.el.addEventListener('mouseup', this.handleMouseUp, {once: true});
      this.selectionClear();
      this.el.removeEventListener('mouseover', this.handleMouseOver);
      return;
    }
    console.log("mouseup is updating selection. this.state.firstSelectedLine is type " + typeof(this.state.firstSelectedLine) + " and this.state.currentLine is type " + typeof(this.state.currentLine))
    this.selectionUpdate(this.state.firstSelectedLine, this.state.currentLine);
    
    this.submitChunk();
    this.selectionClear();
    this.focusCell(0,1);
    this.el.removeEventListener('mouseover', this.handleMouseOver);
  },

  handleEscape() {
    if (this.state.isLineSelecting) {
      console.log("escapeKey: this.state.isLineSelecting was true")
      this.selectionClear();
      this.focusCell(0,1);
    } else {
      console.log("escape -- focus whole grid");
      this.el.focus();
    }
    return;
  },

  handleEnter() {
    if (this.config.mode == "author") {
      activeEl = document.activeElement;
      if (activeEl == this.el) {
        this.focusCell(0,1);
      } 
      else { 
        // console.log("classes: " + document.activeElement.classList);
        if (activeEl.classList.contains("editable")) {
          // console.log("activeEl.dataset.rowIndex: " + Number(activeEl.dataset.rowIndex))
          const cellRow = Number(activeEl.dataset.rowIndex);
          const cellCol = Number(activeEl.dataset.colIndex);
          this.startEdit(cellRow, cellCol);
        } 
        else if (activeEl.dataset.col == "line-num") {
          console.log("Enter: activate line selection mode");
          lineNumberEl = activeEl.firstElementChild;
          if (!lineNumberEl) return;
          lineNumberEl.focus();
          lineNumber = parseInt(lineNumberEl.dataset.lineNumber);
          this.selectionMode(lineNumber);
        }
        else if (this.state.isLineSelecting == true) {
          this.submitChunk();
          this.focusCell(0,1);
          this.selectionClear();
        }
      }  
    }
  },

  destroyed() {
    this.el.removeEventListener('keyup', this.handleKeyUp);
    this.el.removeEventListener('mousedown', this.handleMouseDown);
    this.el.removeEventListener('mouseup', this.handleMouseUp);
    this.el.removeEventListener('mouseover', this.handleMouseOver);

  }
};