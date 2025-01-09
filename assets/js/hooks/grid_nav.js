export const GridNav = {
  // this.el is the whole grid; the element with id annotated-content.
  // this JS hook handles interactions with that grid when there's no
  // editor component open in it.

  mounted() {

    this.config = {};
    this.state = {};
    // this.state.currentLine = this.el.dataset.latestline;

    this.resetConfig();
    if (typeof window.highlightAll === 'function') {
      console.log("highlighting on mount");
      window.highlightAll(this.el);
    }

    // console.log("maxRow: "+ this.config.maxRow + "; maxCol: " + this.config.maxCol);
    console.log("In mounted function (after resetConfig)")
    // this.logActiveEl();

    if (this.config.mode == "author") {
      if (this.el.dataset.latestline) {
      this.focusLine(this.el.dataset.latestline)
      this.focusLineParent();
      }
      // Only need special mouse events for editing, not for read-only
      // Bind event handlers
      this.handleMouseDown = this.handleMouseDown.bind(this);
      this.handleMouseOver = this.handleMouseOver.bind(this);
      this.handleMouseUp = this.handleMouseUp.bind(this);

      // Add event handlers
      this.el.addEventListener('mousedown', this.handleMouseDown);
      this.el.addEventListener('mouseup', this.handleMouseUp);
    }

    this.handleKeyDown = this.handleKeyDown.bind(this);
    this.el.addEventListener('keydown', this.handleKeyDown);
  },

  updated() {
    console.log("DOM refreshed by LiveView");

    if (this.config.mode == "author") {
      this.config.lineCount = this.el.querySelectorAll('[data-line-number]').length;
      // this.state.currentLine = this.el.dataset.latestline; // Not sure I need to do this on updated...maybe
      console.log("in updated fn: currentLine is " + this.state.currentLine);
      if (this.state.currentLine) {
        this.focusLine(this.state.currentLine)
        this.focusLineParent();
        }
    }
    // this.logActiveEl();
    this.config.maxRow = this.el.querySelectorAll('[role="row"]').length - 2;
    window.highlightAll(this.el);

    
    
    if (typeof this.state.firstSelectedLine === 'number') { 
      console.log("in updated: firstSelectedLine = " + this.state.firstSelectedLine)
      this.styleSelected("#ddffdd", this.state.firstSelectedLine, this.state.currentLine);
    }
  },

  resetConfig() {
    // console.log("before resetConfig(). this.config.lineCount = " + this.config.lineCount)
    // console.log("before resetConfig(). this.state.firstSelectedLine = " + this.state.firstSelectedLine)
    // console.log("before resetConfig(). this.state.currentLine = " + this.state.currentLine)

    this.config = {
      mode: this.el.dataset.mode,
      lineCount: this.el.querySelectorAll('[data-line-number]').length,
      maxRow: this.el.querySelectorAll('[role="row"]').length - 2, // minus one because header row doesn't count, minus another because zero-indexed (TODO: make rows start at 1)
      maxCol: this.el.querySelectorAll('[role="columnheader"]').length - 1
    }
    
    this.selectionClear();
    // if (this.state.currentLine != null) {
    //   this.focusLineParent(this.state.currentLine);
    //   }
    // console.log("end of resetConfig: currentLine is " + this.state.currentLine);
  },
  
  logActiveEl() {
    console.log("active element id is " + document.activeElement.id);
    console.log("active element classList is " + document.activeElement.classList);
    console.log("active element dataset is " + [...document.activeElement.attributes]
      .filter(a => a.name.startsWith('data-'))
      .map(a => `${a.name}: ${a.value}`)
      .join(', '));
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

  startEdit(elData) {
    console.log("startEdit triggered");
    console.log("elData.rowIndex: " + elData.rowIndex);
    this.state.currentLine = null;
    const cellRow = Number(elData.rowIndex);
    const cellCol = Number(elData.colIndex);
    // console.log("this.startEdit invoked with " + row + ", " + col)
    this.pushEvent("start_edit", {
      row_index: cellRow,
      col_index: cellCol
    });
    return
  },

  focusCell(row, col) {
    // console.log("this.focusCell: row, col: " + row + ", " + col)    
    const targetCell = this.getCellAt(row, col);
    if (targetCell) targetCell.focus();
  },

  focusLine(line_num) {
    const line_class = '.line-' + line_num;
    console.log("focusLine: line_class is " + line_class);
    const line_el = this.el.querySelector('.line-' + line_num);
    const targetCell = line_el.closest(line_class);
    console.log("targetCell classlist: " + targetCell.classList)
    if (targetCell) targetCell.focus();
    // this.logActiveEl();
  },

  focusLineParent() {
    if (document.activeElement.classList.contains("line-number")) {
      console.log("focusLineParent: active element is a line number; focus the parent cell");
      document.activeElement.parentElement.focus();
    }
    // this.logActiveEl();
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
    console.log("Arrow to " + newRow + ", " + newCol + " from " + cellRow + ", " + cellCol + ".");
    this.focusCell(newRow, newCol);
  },

  selectionStart(lineNumber) {
    this.state.firstSelectedLine = lineNumber;
    this.state.currentLine = lineNumber;
    console.log("selectionStart changed this.state.firstSelectedLine to " + this.state.firstSelectedLine + " with type " + typeof(this.state.firstSelectedLine));
    console.log("selectionStart changed this.state.currentLine to " + this.state.currentLine + " with type " + typeof(this.state.currentLine));
  },

  selectionClear() {
    console.log
    this.unstyleSelected();
    this.state.isLineSelecting = false;
    this.state.firstSelectedLine = null;
    // console.log("in selectionClear: this.state.currentLine is " + this.state.currentLine);
    },

  submitChunk() {
    console.log("submitChunk: pushing rechunk event")
    
    this.pushEvent('rechunk', {start: this.state.firstSelectedLine, end: this.state.currentLine});
    this.resetConfig();
  },

  handleChunkSelection(key) {
    // console.log("handleChunkSelection: shiftKey is " + shiftKey + " with type " + typeof(shiftKey))
    lineNumStr = document.activeElement.dataset.lineNumber;
    if (!lineNumStr) {
      console.log("handleChunkSelection couldn't get a line number from the element")
      return;
    }
    lineNum = Number(lineNumStr);
    console.log("lineNum in handleChunkSelection is " + lineNum)
    if (key == 'V') {
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
    this.state.currentLine = nextLine;
    nextEl.focus();
    // nextEl.classList.add("selectedline");
    console.log("nextEl: " + nextEl);

    if (this.state.firstSelectedLine !== null) {
      console.log("Updating selection by arrow keys. this.state.firstSelectedLine is " + this.state.firstSelectedLine + ", type " + typeof(this.state.firstSelectedLine) + " and last line selected is " + nextLine + ", type " + typeof(nextLine))
      this.styleSelected();

      // this.selectionUpdate(this.state.firstSelectedLine, nextLine);
    }
  },

  styleSelected(color = "#dddddd", num1 = this.state.firstSelectedLine, num2 = this.state.currentLine) {
    // console.log("In styleSelected, num1 = " + num1 + " and num2 = " + num2)
    if (typeof num1 === 'number' && num1 >= 0) {
      for (let i = num1; i <= num2; i++) {
        const elements = document.querySelectorAll(`.line-${i}`);
        elements.forEach(el => {
          // console.log("In styleSelected. At line" + i + ", element style: " + el.style.backgroundColor);
          el.style.backgroundColor = color;
          // console.log("In styleSelected. At line" + i + ", element style: " + el.style.backgroundColor);
        });
        document.querySelector(`.line-${num2 + 1}`).removeAttribute("style");
      }
    }
  },

  unstyleSelected(num1 = this.state.firstSelectedLine, num2 = this.state.currentLine) {
    // console.log("in unstyleSelected. num1 is " + num1 + " and num2 is " + num2)
    // if (num1 >= 0) {
      for (let i = num1; i <= num2; i++) {
        const elements = document.querySelectorAll(`.line-${i}`);
        elements.forEach(el => {
          // console.log("element style: " + el.style.backgroundColor);
          // el.style.backgroundColor = color;
          el.removeAttribute("style");
          // console.log("element style: " + el.style.backgroundColor);
        });
      }
    // }
  },

  // Event handlers
  handleKeyDown(e) {
    // console.log("handleKeyDown triggered with key " + e.key)
    if (this.isEditing()) return;
    if (!['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Escape', 'Enter', 'V'].includes(e.key)) {
      console.log("Got a key that grid_nav doesn't handle");
      return; // This allows default behaviour for all other keys
    }
    e.preventDefault();

    const handlers = {
      Escape: () => this.handleEscape(),
      Enter: () => this.handleEnter(),
      default: () => {
        if (this.state.isLineSelecting) {
          this.handleChunkSelection(e.key); //, e.shiftKey
        } else {
          this.handleArrowNav(e.key);
        }
      }
    };

    (handlers[e.key] || handlers.default)();
  },

  handleMouseDown(e) {
    const lineNumberEl = e.target.closest('.line-number');
    const targetCell = e.target.closest('.grid-cell');
    const activeEl = document.activeElement;
    console.log("handleMouseDown")
    // this.logActiveEl();
    if (this.config.mode == "author") { 
      if (lineNumberEl !== null) {
        e.preventDefault();
        const lineNumber = Number(lineNumberEl.innerText);
        // console.log("mousedown at " + lineNumber);
        lineNumberEl.focus();
        this.state.isLineSelecting = true;
        this.selectionStart(lineNumber);
        this.el.addEventListener('mouseover', this.handleMouseOver);
      }
      else if (activeEl.classList.contains("editable") && targetCell == activeEl) {
        this.startEdit(activeEl.dataset);
      } 
      else if (this.state.isLineSelecting && lineNumberEl == null) {
        // console.log("got a mousedown outside of a line-number element");
        this.selectionClear();
        return;
      } 
    }
  },

  handleMouseOver(e) {
    const lineNumberEl = e.target.closest('.line-number');
    if (!lineNumberEl) return;

    e.preventDefault();
    console.log("handleMouseOver");
    // console.log("mouseover at " + e.target.closest(".line-number").innerText);
    const thisLine = Number(lineNumberEl.innerText);
    // const linediff = thisLine - this.state.currentLine;
    // console.log("linediff: " + linediff );
    this.state.currentLine = thisLine;

    // console.log("mouseover at " + thisLine + ". this.state.currentLine updated to " + this.state.currentLine + " with type " + typeof(this.state.currentLine));
    this.styleSelected();

  },

  handleMouseUp(e) {
    // console.log("mouseup");
    if (!e.target.closest(".line-number")) {
      // console.log("got a mouseup outside of a line-number element");
      this.selectionClear();
      this.el.removeEventListener('mouseover', this.handleMouseOver);
      return;
    }
    if (this.state.firstSelectedLine !== null) {
      // console.log("in handleMouseUp: this.state.firstSelectedLine is " + this.state.firstSelectedLine + " with type " + typeof(this.state.firstSelectedLine) + " and this.state.currentLine is " + this.state.currentLine + " with type " + typeof(this.state.currentLine));
      this.styleSelected();

      if (!this.isEditing()) {
        this.focusLine(this.state.currentLine);
      }
      this.el.removeEventListener('mouseover', this.handleMouseOver);
      this.submitChunk();
    }
  },

  handleEscape() {
    if (this.state.isLineSelecting) {
      console.log("escapeKey: this.state.isLineSelecting was true. Clear selection")
      this.focusLine(this.state.currentLine);
      this.focusLineParent()
      this.selectionClear();
    } else if (document.activeElement === this.el) {
      console.log("escape -- blur #annotated-content div")
      this.el.blur();
      // this.logActiveEl();
    } else {
      console.log("escape -- focus whole grid");
      this.el.focus();
      // this.logActiveEl();
    }
    return;
  },

  handleEnter() {
    activeEl = document.activeElement;
    console.log("handleEnter");
    // this.logActiveEl();
    if (activeEl == this.el) {
      this.focusCell(0,1);
    }
    else if (this.config.mode == "author") { 
      if (activeEl.classList.contains("editable")) {
        this.startEdit(activeEl.dataset);
      } 
      else if (activeEl.dataset.col == "line-num") {
        console.log("Enter: activate line selection mode");
        lineNumberEl = activeEl.firstElementChild;
        if (!lineNumberEl) return;
        lineNumberEl.focus();
        this.state.isLineSelecting = true;
        this.state.currentLine = lineNumberEl.dataset.lineNumber;
      }
      else if (this.state.isLineSelecting == true && this.state.firstSelectedLine !== null) {
        this.submitChunk();
      }
    }
  },

  destroyed() {
    this.el.removeEventListener('keydown', this.handleKeyDown);
    this.el.removeEventListener('mousedown', this.handleMouseDown);
    this.el.removeEventListener('mouseup', this.handleMouseUp);
    this.el.removeEventListener('mouseover', this.handleMouseOver);

  }
};