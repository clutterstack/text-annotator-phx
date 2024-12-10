export const GridNav = {
  // this.el is the whole grid; the element with id annotated-content.
  // this JS hook handles interactions with that grid when there's no
  // editor component open in it.

  mounted() {
    this.config = {
      mode: this.el.dataset.mode,
      lineNumbers: document.querySelectorAll('[data-line-number]'),
      lineCount: document.querySelectorAll('[data-line-number]').length,
      maxRow: this.el.querySelectorAll('[role="row"]').length - 2, // minus one because header row doesn't count, minus another because zero-indexed (TODO: make rows start at 1)
      maxCol: this.el.querySelectorAll('[role="columnheader"]').length - 1
    };

    console.log("maxRow: "+ this.config.maxRow + "; maxCol: " + this.config.maxCol);

    this.state = {
      isLineSelecting: false,
      firstSelectedLine: null,
      currentLine:null,
      currentRow: null,
      currentCol: null
    }

    // Bind event handlers
    this.handleKeyUp = this.handleKeyUp.bind(this);
    this.handleMouseDown = this.handleMouseDown.bind(this);
    this.handleMouseOver = this.handleMouseOver.bind(this);
    this.handleMouseUp = this.handleMouseUp.bind(this);

    this.el.addEventListener('keyup', this.handleKeyUp);
    this.el.addEventListener('mousedown', this.handleMouseDown);
    this.el.addEventListener('mouseup', this.handleMouseUp);
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
    // this.state.currentRow = row;
    // this.state.currentCol = col;
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
    this.state.currentRow = newRow;
    this.state.currentCol = newCol;
    console.log("Arrow to " + newRow + ", " + newCol);
    this.focusCell(newRow, newCol);
  },

  selectionMode(lineNumber) {
    // Enter selecting mode; don't start a selection
    this.state.isLineSelecting = true;
    this.state.currentLine = lineNumber;
  },

  selectionStart(lineNumber) {
    console.log("Starting selection at line " + lineNumber);

    this.selectionMode(lineNumber);
    this.state.firstSelectedLine = lineNumber;
    
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
  },

  handleChunkSelection(key) {
    lineNum = document.activeElement.dataset.lineNumber;
    if (!lineNum) {
      console.log("handleChunkSelection couldn't get a line number from the element")
      return;
    }
    if (key === ' ') {
      console.log("space key in chunkSelection")
      if (this.state.firstSelectedLine == null) {
        // Start new selection
        this.state.firstSelectedLine = this.state.currentLine;
        console.log("starting selection at line " + this.state.currentLine)
        this.pushEvent("start_selection", {
          start: this.state.currentLine,
          end: this.state.currentLine
        });
      } else {
        console.log("firstSelectedLine is not null so don't do anything")
      }
      return;
    } else if (!['ArrowUp', 'ArrowDown'].includes(key)) {
        return;
    }
    // At this point, key must be arrow up or down
    // If selection is started, don't need arrow keys to move without selecting

    const nextLine = key === 'ArrowUp' ? Math.max(this.state.currentLine - 1, this.state.firstSelectedLine) : Math.min(this.state.currentLine + 1, this.config.lineCount - 1);
    this.state.currentLine = nextLine;
    const nextEl = this.config.lineNumbers[nextLine];
    console.log("Arrow to line" + nextEl.innerText + "; this.state.firstSelectedLine is " + this.state.firstSelectedLine)
    nextEl?.focus();

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
    const lineNumber = e.target.closest('.line-number');
    if (this.state.isLineSelecting && lineNumber == null) {
      console.log("got a mousedown outside of a line-number element");
      this.selectionClear();
      return;
    } 
    else if (lineNumber !== null) {
      e.preventDefault();
    
      console.log("mousedown at " + lineNumber);

      const cell = lineNumber.parentElement;
      this.state.currentRow = cell.dataset.rowIndex;
      this.state.currentCol = cell.dataset.colIndex;
      console.log("mousedown updated this.state.currentRow, this.state.currentCol to " + this.state.currentRow + ", " + this.state.currentCol);

      this.selectionStart(Number(lineNumber.innerText));
      console.log("on mousedown, changed this.state.firstSelectedLine to " + this.state.firstSelectedLine);
      console.log("also, typeof this.state.firstSelectedLine is " + typeof(this.state.firstSelectedLine));
      // this.setupDragHandlers();
      this.el.addEventListener('mouseover', this.handleMouseOver);
    };
  },

  handleMouseOver(e) {
    const lineNumber = e.target.closest('.line-number');
    if (!lineNumber) return;

    e.preventDefault();
    const linenumber = e.target.closest(".line-number");
    console.log("handleMouseOver");
    // console.log("mouseover at " + e.target.closest(".line-number").innerText);
    linenumber.classList.remove("selectedline"); // in case I'm duplicating this class
    const linediff = linenumber.innerText - this.state.currentLine;
    console.log("linediff: " + linediff );
    if (linediff > 0) {
      console.log("linediff is " + linediff + ". Adding class selectedline.")
      linenumber.classList.add("selectedline");
    } else if (linediff < 0) {
      console.log("linediff is " + linediff + ". Removing class selectedline.")
      linenumber.classList.remove("selectedline");
    }
    this.state.currentLine = Number(linenumber.innerText);

    console.log("mouseover at " + linenumber.innerText + ". this.state.currentLine updated to " + this.state.currentLine)
    console.log("also, typeof this.state.currentLine is now" + typeof(this.state.currentLine))
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
    this.focusCell(0,1);
    this.selectionClear();
    this.el.removeEventListener('mouseover', this.handleMouseOver);
  },

  handleEscape() {
    if (this.state.isLineSelecting) {
      console.log("escapeKey: this.state.isLineSelecting was true")
      console.log("this.state.currentRow and this.state.currentCol are " + this.state.currentRow + ", " + this.state.currentCol)

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
        // this.state.currentRow = 0;
        // this.state.currentCol = 1;
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
          console.log("Enter: activate line selection");
          console.log("this.state.firstSelectedLine: " + this.state.firstSelectedLine)

          lineNumberEl = activeEl.firstElementChild;
          if (!lineNumberEl) return;
          lineNumberEl.focus();
          lineNumber = parseInt(lineNumberEl.dataset.lineNumber);
          this.state.currentLine = Number(lineNumber);
          this.selectionMode(lineNumber);
        }
        else if (this.state.isLineSelecting == true) {
          this.submitChunk();
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