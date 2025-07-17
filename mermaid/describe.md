# Describe Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press leader+d on commit| C[Describe Commit]
    B -->|leader+a action menu| D[Action Menu]
    
    %% Describe Commit Flow
    C --> E[Get commit under cursor]
    E --> F{Valid Commit?}
    F -->|No| G[Show error - no commit selected]
    F -->|Yes| H[set_description]
    
    %% Action Menu Flow
    D --> I{Menu Selection}
    I -->|Single Selection| J[Describe commit leader+d]
    J --> E
    
    %% Core Describe Process
    H --> K[Get current commit description]
    K --> L[commands.execute_with_immutable_prompt]
    L --> M[jj log --no-graph -r change_id -T description]
    M --> N[Execute command]
    N --> O{Success?}
    
    O -->|Yes| P[Parse current description]
    O -->|No| Q[Show error - cannot get description]
    
    %% Description Input
    P --> R[Show description input dialog]
    R --> S[Pre-populate with current description]
    S --> T[vim.ui.input prompt]
    T --> U{User Input}
    
    U -->|Cancel/Empty| V[Cancel operation]
    U -->|New Description| W[Validate input]
    
    %% Validation
    W --> X{Description Valid?}
    X -->|No| Y[Show error - invalid description]
    X -->|Yes| Z[Build jj describe command]
    
    %% Execute Describe
    Z --> AA[commands.execute_with_immutable_prompt]
    AA --> BB[jj describe -r change_id -m new_description]
    BB --> CC[Execute command]
    CC --> DD{Success?}
    
    DD -->|Yes| EE[Show success notification]
    DD -->|No| FF[Show error message]
    
    %% Success Path
    EE --> GG[Show description change summary]
    GG --> HH[Refresh log display]
    HH --> II[Update commit display]
    II --> JJ[Show updated description]
    
    %% Description Display
    JJ --> KK[Update commit in log]
    KK --> LL[Apply syntax highlighting]
    LL --> MM[Show description preview]
    MM --> NN[Update commit graph]
    
    %% Input Dialog Features
    R --> OO[Configure input dialog]
    OO --> PP[Set dialog title]
    PP --> QQ[Set placeholder text]
    QQ --> RR[Set default value]
    RR --> SS[Enable multiline input]
    
    %% Pre-population Logic
    S --> TT[Clean current description]
    TT --> UU[Remove template markers]
    UU --> VV[Format for editing]
    VV --> WW[Set cursor position]
    
    %% Validation Rules
    W --> XX[Check description length]
    XX --> YY[Check for invalid characters]
    YY --> ZZ[Check for empty description]
    ZZ --> AAA[Validate description format]
    
    %% Error Handling
    G --> BBB[Return to previous state]
    Q --> BBB
    Y --> BBB
    FF --> BBB
    V --> BBB
    
    %% Description Processing
    Z --> CCC[Escape special characters]
    CCC --> DDD[Handle multiline descriptions]
    DDD --> EEE[Format for jj command]
    EEE --> FFF[Build command arguments]
    
    %% Success Feedback
    GG --> GGG[Show before/after comparison]
    GGG --> HHH[Display change summary]
    HHH --> III[Show commit ID]
    III --> JJJ[Show timestamp]
    
    %% Commit Update
    II --> KKK[Update commit object]
    KKK --> LLL[Refresh commit data]
    LLL --> MMM[Update display cache]
    MMM --> NNN[Trigger re-render]
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef validation fill:#fff3e0
    classDef execution fill:#e8f5e8
    classDef command fill:#fff3e0
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    classDef input fill:#f3e5f5
    classDef display fill:#e8f5e8
    
    class A,B,C,D userAction
    class E,F,H,W,X,XX,YY,ZZ,AAA validation
    class K,L,M,N,AA,BB,CC,Z,CCC,DDD,EEE,FFF execution
    class M,BB command
    class EE,GG,HH,II,JJ,KK,LL,MM,NN,GGG,HHH,III,JJJ,KKK,LLL,MMM,NNN success
    class G,Q,Y,FF,BBB error
    class R,S,T,U,OO,PP,QQ,RR,SS,TT,UU,VV,WW input
    class display display
```

## Key Features

- **Current Description**: Shows existing description for editing
- **Interactive Input**: Uses vim.ui.input for description editing
- **Validation**: Ensures description is valid before applying
- **Pre-population**: Loads current description for easy editing

## Description Input

The describe command provides:
- **Current Description**: Pre-populated with existing description
- **Interactive Dialog**: Native vim input dialog
- **Multiline Support**: Handles multiline descriptions
- **Validation**: Checks for valid description format
- **Cancellation**: Can cancel without changes

## Input Dialog Features

- **Title**: "Set commit description"
- **Placeholder**: Current description or helpful text
- **Default Value**: Current commit description
- **Multiline**: Support for detailed descriptions
- **Validation**: Real-time validation feedback

## Description Processing

- **Special Characters**: Proper escaping for shell execution
- **Multiline Handling**: Preserves line breaks and formatting
- **Template Cleaning**: Removes jj template markers
- **Format Validation**: Ensures description meets requirements

## Success Feedback

After successful description change:
- **Before/After**: Shows old vs new description
- **Change Summary**: Highlights what was modified
- **Commit Info**: Shows affected commit ID and timestamp
- **Visual Update**: Refreshes log display with new description

## File Locations

- **Core**: `lua/jj-nvim/jj/describe.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:566-567`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua` (context-sensitive)
- **Keybinding**: `<leader>d` for describe operation